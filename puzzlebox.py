#!/usr/bin/env python3
"""
Puzzle Box Generator - Web Server
Wraps the C generator binary with a modern web interface
"""

import os
import re
import subprocess
import tempfile
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json

# Configuration
PORT = int(os.environ.get('PORT', 8080))
GENERATOR_PATH = Path(__file__).parent / "generator" / "puzzlebox"
STATIC_DIR = Path(__file__).parent


class PuzzleBoxHandler(SimpleHTTPRequestHandler):
    """Custom HTTP handler for Puzzle Box Generator"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC_DIR), **kwargs)
    
    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        
        if parsed.path == "/api/generate":
            self.handle_generate(parsed.query)
        elif parsed.path == "/api/health":
            self.send_json({"status": "ok", "generator": GENERATOR_PATH.exists()})
        elif parsed.path == "/api/decode":
            self.handle_decode(parsed.query)
        else:
            super().do_GET()
    
    def handle_decode(self, query_string):
        """Decode a share ID back to parameters"""
        import base64
        params = parse_qs(query_string)
        
        share_id = params.get('id', [''])[0]
        if not share_id:
            self.send_json({"error": "No ID provided"}, status=400)
            return
        
        try:
            # Decode the base64 ID back to parameters
            decoded = base64.urlsafe_b64decode(share_id + '==').decode()  # Add padding
            param_pairs = decoded.split('&')
            result = {}
            for pair in param_pairs:
                if '=' in pair:
                    key, value = pair.split('=', 1)
                    result[key] = value
            
            self.send_json({"params": result, "success": True})
        except Exception as e:
            self.send_json({"error": f"Invalid ID: {str(e)}"}, status=400)
    
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()
    
    def send_cors_headers(self):
        """Add CORS headers"""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
    
    def send_json(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def send_file_response(self, data, filename, content_type):
        """Send file download response"""
        if isinstance(data, str):
            data = data.encode('utf-8')
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.send_header("Content-Length", len(data))
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(data)
    
    def handle_generate(self, query_string):
        """Generate puzzle box using the C binary"""
        params = parse_qs(query_string)
        
        # Check for polyhedron extraction mode (for MakerWorld)
        extract_polyhedron = 'polyhedron' in params and params['polyhedron'][0].lower() in ('1', 'true', 'on')
        
        # Build command line arguments
        args = [str(GENERATOR_PATH)]
        
        # Map URL parameters to command line options
        param_map = {
            # Flags (no value)
            'l': '--stl',
            'R': '--resin',
            'i': '--inside',
            'f': '--flip',
            'q': '--core-solid',
            'v': '--park-vertical',
            'W': '--base-wide',
            'd': '--text-slow',
            'O': '--text-outset',
            'V': '--symmetric-cut',
            'Q': '--test',
            # Values
            'm': '--parts',
            'c': '--core-diameter',
            'h': '--core-height',
            'C': '--core-gap',
            'E': '--text-end',
            'I': '--text-inside',
            'S': '--text-side',
            'n': '--part',
            'N': '--nubs',
            'H': '--helix',
            'b': '--base-height',
            'w': '--part-thickness',
            't': '--maze-thickness',
            'z': '--maze-step',
            'M': '--maze-margin',
            'X': '--maze-complexity',
            'p': '--park-thickness',
            'B': '--base-thickness',
            'Z': '--base-gap',
            'g': '--clearance',
            'y': '--nub-r-clearance',
            's': '--outer-sides',
            'r': '--outer-round',
            'G': '--grip-depth',
            'D': '--text-depth',
            'F': '--text-font',
            'e': '--text-font-end',
            'T': '--text-side-scale',
            'U': '--text-end-scale',
            'J': '--text-inside-scale',
            'L': '--logo-depth',
        }
        
        # Flags that don't take values
        flag_params = {'l', 'R', 'i', 'f', 'q', 'v', 'W', 'd', 'O', 'V', 'Q'}
        
        generate_stl = False
        
        # Check if physical watermark is enabled (hidden signature in slicer only)
        add_physical_watermark = 'watermark' in params and params['watermark'][0].lower() in ('1', 'true', 'on')
        
        for short, long_opt in param_map.items():
            if short in params:
                value = params[short][0] if params[short] else ""
                
                if short in flag_params:
                    if value and value.lower() not in ('', '0', 'false', 'off'):
                        args.append(long_opt)
                        if short == 'l':
                            generate_stl = True
                else:
                    if value and value.strip():
                        args.append(f"{long_opt}={value}")
        
        try:
            result = subprocess.run(
                args,
                capture_output=True,
                timeout=120,
                cwd=str(GENERATOR_PATH.parent)
            )
            
            if result.returncode != 0:
                error_msg = result.stderr.decode() if result.stderr else "Unknown error"
                self.send_json({"error": error_msg}, status=500)
                return
            
            output = result.stdout
            
            # If polyhedron extraction mode, extract individual parts for MakerWorld
            if extract_polyhedron:
                scad_content = output.decode('utf-8')
                # Add watermarks (code + optional physical)
                clean_scad = self.strip_header_comments(scad_content, add_physical_watermark, params)
                parts = self.extract_individual_parts(scad_content, add_physical_watermark, params)
                
                # Generate share ID that can regenerate this exact puzzle
                import base64
                param_str = '&'.join(f"{k}={v[0]}" for k, v in sorted(params.items()) if v and v[0])
                share_id = base64.urlsafe_b64encode(param_str.encode()).decode()
                
                self.send_json({
                    "parts": parts,
                    "full_scad": clean_scad,
                    "share_id": share_id,
                    "message": "Individual parts extracted - copy each one separately"
                })
                return
            
            if generate_stl:
                filename = self.build_filename(params) + ".stl"
                content_type = "model/stl"
            else:
                filename = self.build_filename(params) + ".scad"
                content_type = "application/x-openscad"
            
            self.send_file_response(output, filename, content_type)
            
        except subprocess.TimeoutExpired:
            self.send_json({"error": "Generation timed out."}, status=500)
        except FileNotFoundError:
            self.send_json({"error": "Generator binary not found."}, status=500)
        except Exception as e:
            self.send_json({"error": str(e)}, status=500)
    
    def add_watermark(self, scad_content, add_physical=False, params=None):
        """Add hidden watermark signature to prove ownership"""
        import base64
        import hashlib
        import time
        
        # Always generate timestamp for the hidden _pb marker
        timestamp = int(time.time())
        
        # Generate a reproducible ID from parameters (allows regeneration)
        if params:
            # Encode parameters into the ID
            param_str = '&'.join(f"{k}={v[0]}" for k, v in sorted(params.items()) if v and v[0])
            signature_hash = base64.urlsafe_b64encode(param_str.encode()).decode()[:32]
        else:
            signature_data = f"PuzzleBoxGen-RC-{timestamp}"
            signature_hash = hashlib.sha256(signature_data.encode()).hexdigest()[:16]
        
        lines = scad_content.split('\n')
        result_lines = []
        
        # Generate share ID from params
        if params:
            param_str = '&'.join(f"{k}={v[0]}" for k, v in sorted(params.items()) if v and v[0])
            share_id = base64.urlsafe_b64encode(param_str.encode()).decode()
        else:
            share_id = signature_hash
        
        # Add OpenSCAD Customizer metadata (shows in MakerWorld Customize panel)
        result_lines.append("/* [About This Model] */")
        result_lines.append('_generator = "PuzzleBoxGenerator"; // Generated by')
        result_lines.append('_creator = "Rogerio Camorim"; // Original Creator')
        result_lines.append('_version = "1.0.0"; // Version')
        result_lines.append(f'_share_id = "{share_id}"; // Share ID (use to regenerate)')
        result_lines.append("")
        result_lines.append("/* [Hidden] */")
        result_lines.append("")
        
        watermark_added = False
        physical_watermark_added = False
        
        for line in lines:
            # Skip original header comments (we replaced them)
            if line.startswith('// Puzzle Box Generator') or line.startswith('// Created '):
                continue
            if line.startswith('// ') and '=' in line and ':' not in line:
                continue  # Skip parameter comments
            
            result_lines.append(line)
            
            # Add hidden watermark inside the scale block (looks like valid OpenSCAD)
            if not watermark_added and 'scale(0.001)' in line:
                # This looks like a legitimate variable but encodes ownership
                # The numbers encode: R=82, C=67 (ASCII for RC - Rogerio Camorim)
                result_lines.append(f"_pb=[82,67,{timestamp % 100000}]; // config")
                watermark_added = True
            
            # Add physical watermark (hidden inside base, visible only in slicer)
            # Z=170 starts after first layer for all common heights (0.16, 0.2, 0.24mm)
            # Height=500 (0.5mm) ensures it spans 2-4 layers regardless of layer height
            if add_physical and not physical_watermark_added and '// Part 1' in line:
                result_lines.append("// Hidden watermark - visible only in slicer layers 2-4")
                result_lines.append("translate([0,0,170])linear_extrude(height=500,convexity=2)")
                result_lines.append("  text(\"RC\",size=2000,font=\"Liberation Sans:style=Bold\",halign=\"center\",valign=\"center\");")
                physical_watermark_added = True
        
        return '\n'.join(result_lines)
    
    def strip_header_comments(self, scad_content, add_physical=False, params=None):
        """Add watermark instead of stripping - for ownership proof"""
        return self.add_watermark(scad_content, add_physical, params)
    
    def extract_individual_parts(self, scad_content, add_physical_watermark=False, params=None):
        """Extract each part as a complete, standalone OpenSCAD file"""
        parts = []
        lines = scad_content.split('\n')
        
        # Extract header comments and modules
        header_lines = []
        module_lines = []
        in_scale_block = False
        scale_line_idx = -1
        
        for i, line in enumerate(lines):
            if line.startswith('//'):
                header_lines.append(line)
            elif line.startswith('module '):
                module_lines.append(line)
            elif line.startswith('scale('):
                scale_line_idx = i
                break
        
        # Find part boundaries within the scale block
        part_ranges = []
        current_part_start = -1
        current_part_name = ""
        
        for i, line in enumerate(lines):
            if '// Part ' in line and line.strip().startswith('// Part '):
                # Save previous part
                if current_part_start >= 0:
                    part_ranges.append((current_part_start, i, current_part_name))
                
                # Start new part
                match = re.search(r'// (Part \d+)', line)
                if match:
                    current_part_name = match.group(1)
                    current_part_start = i
        
        # Add last part (ends at closing brace)
        if current_part_start >= 0:
            # Find the closing brace of scale block
            end_idx = len(lines) - 1
            for i in range(len(lines) - 1, current_part_start, -1):
                if lines[i].strip() == '}':
                    end_idx = i
                    break
            part_ranges.append((current_part_start, end_idx, current_part_name))
        
        # Generate reproducible signature from parameters
        import base64
        import time
        timestamp = int(time.time())
        
        if params:
            param_str = '&'.join(f"{k}={v[0]}" for k, v in sorted(params.items()) if v and v[0])
            signature_hash = base64.urlsafe_b64encode(param_str.encode()).decode()[:24]
        else:
            import hashlib
            signature_data = f"PuzzleBoxGen-RC-{timestamp}"
            signature_hash = hashlib.sha256(signature_data.encode()).hexdigest()[:16]
        
        # Build each part as complete OpenSCAD
        raw_parts = []
        for start_idx, end_idx, part_name in part_ranges:
            part_lines = lines[start_idx:end_idx]
            
            # Generate share ID from params
            import base64 as b64
            if params:
                param_str = '&'.join(f"{k}={v[0]}" for k, v in sorted(params.items()) if v and v[0])
                share_id = b64.urlsafe_b64encode(param_str.encode()).decode()
            else:
                share_id = signature_hash
            
            # Build complete code with hidden ownership watermark
            code_lines = []
            # OpenSCAD Customizer metadata (shows in MakerWorld Customize panel)
            code_lines.append("/* [About This Model] */")
            code_lines.append('_part = "{PART_NAME}"; // Part Name')
            code_lines.append('_generator = "PuzzleBoxGenerator"; // Generated by')
            code_lines.append('_creator = "Rogerio Camorim"; // Original Creator')
            code_lines.append('_version = "1.0.0"; // Version')
            code_lines.append(f'_share_id = "{share_id}"; // Share ID (use to regenerate)')
            code_lines.append("")
            code_lines.append("/* [Hidden] */")
            code_lines.append("")
            
            # Add modules
            for mod in module_lines:
                code_lines.append(mod)
            if module_lines:
                code_lines.append("")
            
            # Add scale wrapper and part content with hidden watermark
            code_lines.append("scale(0.001) {")
            # Hidden watermark: 82=R, 67=C (ASCII for initials), plus timestamp fragment
            code_lines.append(f"  _pb=[82,67,{timestamp % 100000}]; // config")
            
            # Add physical watermark to Inner Core (the innermost part)
            # This is tiny text inside the base, visible only in slicer
            # Z=170 starts after first layer for all common heights (0.16, 0.2, 0.24mm)
            # Height=500 (0.5mm) ensures it spans 2-4 layers regardless of layer height
            if add_physical_watermark and part_name == "Part 1":  # Part 1 is Inner Core (before reversal)
                code_lines.append("  // Hidden watermark - visible only in slicer layers 2-4")
                code_lines.append("  translate([0,0,170])linear_extrude(height=500,convexity=2)")
                code_lines.append("    text(\"RC\",size=2000,font=\"Liberation Sans:style=Bold\",halign=\"center\",valign=\"center\");")
            
            for line in part_lines:
                stripped = line.strip()
                if not stripped:
                    continue
                # Skip the positioning translate (first one with large coordinates)
                if stripped.startswith('translate([') and any(c.isdigit() for c in stripped[:30]):
                    # Check if it's a large positioning translate (> 10000)
                    nums = re.findall(r'\d+', stripped[:50])
                    if nums and int(nums[0]) > 10000:
                        continue
                code_lines.append(f"  {stripped}")
            
            code_lines.append("}")
            
            raw_parts.append({
                "original_name": part_name,
                "code": '\n'.join(code_lines)
            })
        
        # Reverse order: generator outputs inner→outer, we want outer→inner
        raw_parts.reverse()
        
        # Rename parts with user-friendly names
        total_parts = len(raw_parts)
        parts = []
        
        for i, part in enumerate(raw_parts):
            if i == 0:
                friendly_name = "Outer Box"
            elif i == total_parts - 1:
                friendly_name = "Inner Core"
            else:
                friendly_name = f"Puzzle Layer {i}"
            
            # Replace placeholder in code
            code = part["code"].replace("{PART_NAME}", friendly_name)
            
            parts.append({
                "name": friendly_name,
                "code": code
            })
        
        return parts
    
    def extract_polyhedrons(self, scad_content):
        """Extract complete, valid OpenSCAD code for each part"""
        parts = []
        lines = scad_content.split('\n')
        
        # First, extract module definitions (needed for complete code)
        modules = []
        for line in lines:
            if line.startswith('module '):
                modules.append(line)
        
        # Find part boundaries
        part_starts = []
        for i, line in enumerate(lines):
            if line.strip().startswith('// Part '):
                match = re.search(r'// (Part \d+)', line)
                if match:
                    part_starts.append((i, match.group(1), line.strip()))
        
        # Extract each part
        for idx, (start_line, part_name, part_comment) in enumerate(part_starts):
            # Find end of this part (start of next part or end of scale block)
            if idx + 1 < len(part_starts):
                end_line = part_starts[idx + 1][0]
            else:
                # Find the closing brace of scale block
                end_line = len(lines)
                for i in range(len(lines) - 1, start_line, -1):
                    if lines[i].strip() == '}':
                        end_line = i
                        break
            
            # Extract part lines (skip the comment line itself)
            part_lines = lines[start_line + 1:end_line]
            
            # Check if there's actual geometry
            part_content = '\n'.join(part_lines)
            if 'polyhedron(' not in part_content:
                continue
            
            # Build complete OpenSCAD code for this part
            code = self.build_complete_part(part_name, part_comment, part_lines, modules)
            if code:
                parts.append({
                    "name": part_name,
                    "code": code
                })
        
        return parts
    
    def build_complete_part(self, part_name, part_comment, part_lines, modules):
        """Build a complete, valid OpenSCAD file for a single part"""
        code_lines = []
        
        # Header
        code_lines.append(f"// {part_name} - Generated Puzzle Box")
        code_lines.append("// Paste this complete code into MakerWorld Parametric Model Maker")
        code_lines.append("")
        
        # Include any required modules
        for module in modules:
            code_lines.append(module)
        if modules:
            code_lines.append("")
        
        # Scale wrapper (coordinates are in micrometers)
        code_lines.append("scale(0.001) {")
        code_lines.append(f"  {part_comment}")
        
        # Add the part geometry
        # Include all geometry primitives, not just polyhedron
        geometry_keywords = ['polyhedron(', 'cylinder(', 'cube(', 'sphere(', 
                            'rotate(', 'for(', 'translate(', 'difference(', 
                            'union(', 'intersection(', 'hull(', 'minkowski(']
        
        # Track brace depth to handle nested structures
        content = '\n'.join(part_lines)
        
        # Remove leading translate that positions the part (first one only)
        # Keep other translates that are part of the geometry
        first_translate_removed = False
        filtered_lines = []
        
        for line in part_lines:
            stripped = line.strip()
            if not stripped:
                continue
            
            # Skip the first translate (positioning)
            if not first_translate_removed and stripped.startswith('translate(['):
                first_translate_removed = True
                continue
            
            # Include geometry-related lines
            if any(kw in stripped for kw in geometry_keywords) or stripped in ['{', '}', '};']:
                filtered_lines.append(stripped)
        
        # Join and add proper indentation
        for line in filtered_lines:
            code_lines.append(f"  {line}")
        
        code_lines.append("}")
        
        return '\n'.join(code_lines)
    
    def build_filename(self, params):
        """Build a descriptive filename"""
        parts = ["puzzlebox"]
        
        if 'm' in params and params['m'][0]:
            parts.append(f"{params['m'][0]}parts")
        if 'c' in params and params['c'][0]:
            parts.append(f"{params['c'][0]}c")
        if 'h' in params and params['h'][0]:
            parts.append(f"{params['h'][0]}h")
        if 'X' in params and params['X'][0]:
            parts.append(f"X{params['X'][0]}")
        
        return "-".join(parts)
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[{self.log_date_time_string()}] {args[0]}")


def build_generator():
    """Build the C generator if needed"""
    if GENERATOR_PATH.exists():
        return True
    
    print("⚠️  Generator binary not found. Building...")
    
    gcc_path = "/opt/homebrew/bin/gcc-15"
    if not Path(gcc_path).exists():
        result = subprocess.run(["which", "gcc"], capture_output=True)
        gcc_path = result.stdout.decode().strip() or "gcc"
    
    build_cmd = [
        gcc_path,
        "-O", "-o", "puzzlebox", "puzzlebox.c",
        "-L/opt/homebrew/lib", "-I/opt/homebrew/include",
        "-lpopt", "-lm", "-g", "-D_GNU_SOURCE"
    ]
    
    try:
        result = subprocess.run(build_cmd, cwd=str(GENERATOR_PATH.parent), capture_output=True)
        if result.returncode == 0:
            print("   ✅ Generator built successfully!")
            return True
        else:
            print(f"   ❌ Build failed: {result.stderr.decode()}")
            return False
    except Exception as e:
        print(f"   ❌ Build failed: {e}")
        return False


def main():
    """Start the server"""
    # Build generator if needed
    if not build_generator():
        print("\nCannot start without generator. Please ensure:")
        print("  1. The generator/ folder contains puzzlebox.c")
        print("  2. GCC and popt are installed (brew install gcc popt)")
        return
    
    # Check for OpenSCAD
    try:
        result = subprocess.run(["which", "openscad"], capture_output=True)
        if result.returncode != 0:
            print("⚠️  OpenSCAD not found. STL generation will not work.")
            print("   Install with: brew install --cask openscad")
        else:
            print("✅ OpenSCAD found - STL generation enabled")
    except:
        pass
    
    print(f"\n🧩 Puzzle Box Generator")
    print(f"   Server running at: http://localhost:{PORT}")
    print(f"   Generator: {GENERATOR_PATH}")
    print(f"\n   Press Ctrl+C to stop\n")
    
    server = HTTPServer(("", PORT), PuzzleBoxHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\n👋 Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
