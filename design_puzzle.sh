#!/bin/bash
#
# PuzzleBox Designer Script
# Makes it easy to generate and preview custom puzzle boxes
#
# Usage examples:
#   ./design_puzzle.sh                          # Default 2-part puzzle
#   ./design_puzzle.sh -c 35 -h 60              # Larger core (35mm x 60mm)
#   ./design_puzzle.sh -m 3 -s 8                # 3 parts, octagonal shape
#   ./design_puzzle.sh -E "AB" -S "HAPPY BIRTHDAY"  # With text
#   ./design_puzzle.sh --help                   # Show all options
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/designs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check if help is requested
if [[ "$1" == "--help" ]] || [[ "$1" == "-?" ]]; then
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    PUZZLEBOX DESIGNER                            ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║ Creates custom maze puzzle boxes for 3D printing                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "COMMON OPTIONS:"
    echo "  Size:"
    echo "    -c, --core-diameter=mm    Inner diameter (default: 30)"
    echo "    -h, --core-height=mm      Inner height (default: 50)"
    echo "    -m, --parts=N             Number of nesting parts (default: 2)"
    echo ""
    echo "  Shape:"
    echo "    -s, --outer-sides=N       Number of sides (0=round, 7=heptagon)"
    echo "                              Examples: 6=hexagon, 8=octagon"
    echo ""
    echo "  Maze:"
    echo "    -X, --maze-complexity=N   Difficulty -10 to 10 (default: 5)"
    echo "    -i, --inside              Put maze on inside (harder)"
    echo "    -f, --flip                Alternating inside/outside"
    echo ""
    echo "  Text:"
    echo "    -E, --text-end=\"AB\"       Initials on lid"
    echo "    -S, --text-side=\"TEXT\"    Text around sides"
    echo "    -I, --text-inside=\"X\"     Text inside lid"
    echo ""
    echo "  Printing:"
    echo "    -R, --resin               Tighter clearances for resin"
    echo "    -n, --part=N              Generate only part N (0=all)"
    echo ""
    echo "  Output:"
    echo "    -l, --stl                 Generate STL directly (needs OpenSCAD)"
    echo ""
    echo "EXAMPLES:"
    echo "  # Simple 2-part round puzzle, 30mm diameter"
    echo "  ./design_puzzle.sh"
    echo ""
    echo "  # Hexagonal puzzle with initials"  
    echo "  ./design_puzzle.sh -s 6 -E \"JD\""
    echo ""
    echo "  # Large 3-part octagonal gift box with message"
    echo "  ./design_puzzle.sh -c 40 -h 70 -m 3 -s 8 -S \"HAPPY\\\\BIRTHDAY\""
    echo ""
    echo "  # Hard mode: maze on inside"
    echo "  ./design_puzzle.sh -i -X 8"
    echo ""
    echo "Output files are saved to: $OUTPUT_DIR"
    echo ""
    exit 0
fi

# Generate a descriptive filename from arguments
ARGS_FOR_NAME=$(echo "$@" | tr ' ' '_' | tr -cd '[:alnum:]_-')
if [ -z "$ARGS_FOR_NAME" ]; then
    ARGS_FOR_NAME="default"
fi
OUTPUT_FILE="${OUTPUT_DIR}/puzzle_${TIMESTAMP}_${ARGS_FOR_NAME}.scad"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    PUZZLEBOX DESIGNER                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Generating puzzle with parameters: $@"
echo ""

# Run the puzzlebox generator
"${SCRIPT_DIR}/puzzlebox" "$@" --out-file "$OUTPUT_FILE"

if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    echo "✓ Generated: $OUTPUT_FILE"
    echo ""
    
    # Check if OpenSCAD is available
    if command -v openscad &> /dev/null; then
        echo "Opening in OpenSCAD for preview..."
        openscad "$OUTPUT_FILE" &
    elif [ -d "/Applications/OpenSCAD.app" ]; then
        echo "Opening in OpenSCAD for preview..."
        open -a OpenSCAD "$OUTPUT_FILE"
    else
        echo "OpenSCAD not found. Install it to preview the design."
        echo "Download from: https://openscad.org/downloads.html"
        echo ""
        echo "You can manually open the file: $OUTPUT_FILE"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "NEXT STEPS:"
    echo "  1. In OpenSCAD, press F5 to preview (fast)"
    echo "  2. Adjust parameters by re-running this script"
    echo "  3. When happy, press F6 to render, then export as STL"
    echo ""
    echo "  Or generate STL directly (slower):"
    echo "  ./design_puzzle.sh $@ -l"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "✗ Error generating puzzle"
    exit 1
fi

