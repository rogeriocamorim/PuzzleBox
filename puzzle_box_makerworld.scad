// Puzzle Box - MakerWorld Parametric Version
// Paste the generated path from the website into the path_data parameter
// Compatible with MakerWorld Parametric Model Maker

include <BOSL2/*.scad>;

/* [Puzzle Parameters] */
// Paste the maze path string here (generated from website)
path_data = "RUURRDDLUURRDDRRUU";

// Random seed for dead ends (change for different dead end patterns)
dead_end_seed = 42; // [1:999]

/* [Dimensions] */
// Outer diameter of the puzzle box
outer_diameter = 40; // [30:80]

// Total height of the puzzle box
total_height = 50; // [40:100]

// Wall thickness
wall_thickness = 2; // [1.5:0.5:4]

/* [Maze Settings] */
// Number of columns in the maze
maze_columns = 8; // [4:16]

// Step height for each maze row (mm)
maze_step = 4; // [2:0.5:8]

// Maze groove depth
groove_depth = 1.5; // [1:0.5:3]

// Maze groove width
groove_width = 2; // [1.5:0.5:4]

/* [Display Options] */
// Which part to show
show_part = "both"; // [inner, outer, both]

// Explode view distance
explode_distance = 0; // [0:50]

/* [Hidden] */
$fn = 64;

// Parse path string into array of moves
function parse_path(str, i=0) = 
    i >= len(str) ? [] :
    let(c = str[i])
    let(move = c == "U" || c == "u" ? [0, 1] :
               c == "D" || c == "d" ? [0, -1] :
               c == "R" || c == "r" ? [1, 0] :
               c == "L" || c == "l" ? [-1, 0] : [0, 0])
    concat([move], parse_path(str, i+1));

// Build path coordinates from moves
function build_coords(moves, start=[0,0], i=0) =
    i >= len(moves) ? [start] :
    let(next = [(start[0] + moves[i][0] + maze_columns) % maze_columns, start[1] + moves[i][1]])
    concat([start], build_coords(moves, next, i+1));

// Check if two cells are connected in the path
function cells_connected(coords, c1, r1, c2, r2) =
    let(count = len(coords))
    count < 2 ? false :
    let(matches = [for(i=[0:count-2]) 
        if((coords[i][0] == c1 && coords[i][1] == r1 && 
            coords[i+1][0] == c2 && coords[i+1][1] == r2) ||
           (coords[i][0] == c2 && coords[i][1] == r2 && 
            coords[i+1][0] == c1 && coords[i+1][1] == r1)) 1])
    len(matches) > 0;

// Get the parsed path
moves = parse_path(path_data);
path_coords = build_coords(moves);
path_length = len(path_coords);
maze_rows = max([for(p=path_coords) p[1]]) + 2;

echo(str("Path length: ", path_length));
echo(str("Maze rows: ", maze_rows));

// Calculate dimensions
inner_radius = outer_diameter/2 - wall_thickness*2;
outer_radius = outer_diameter/2;
col_angle = 360 / maze_columns;

// Module to create the maze walls for the outer part (grooves inside)
module maze_grooves() {
    z_base = total_height/4;
    
    for(row = [0:maze_rows-1]) {
        z = z_base + row * maze_step;
        
        for(col = [0:maze_columns-1]) {
            ang = col * col_angle;
            next_col = (col + 1) % maze_columns;
            
            // Horizontal groove (around circumference)
            h_connected = cells_connected(path_coords, col, row, next_col, row);
            if(h_connected) {
                rotate([0, 0, ang])
                translate([0, 0, z])
                rotate_extrude(angle = col_angle + 5, $fn=maze_columns*4)
                translate([inner_radius - groove_depth/2, 0])
                    square([groove_depth, groove_width], center=true);
            }
            
            // Vertical groove (up/down)
            v_connected = cells_connected(path_coords, col, row, col, row+1);
            if(v_connected) {
                rotate([0, 0, ang + col_angle/2])
                translate([inner_radius - groove_depth/2, 0, z + maze_step/2])
                    cube([groove_depth, groove_width, maze_step + groove_width], center=true);
            }
        }
    }
    
    // Entry groove at bottom
    entry_col = path_coords[0][0];
    rotate([0, 0, entry_col * col_angle + col_angle/2])
    translate([inner_radius - groove_depth/2, 0, z_base/2])
        cube([groove_depth, groove_width, z_base + groove_width], center=true);
    
    // Exit groove at top  
    exit_col = path_coords[len(path_coords)-1][0];
    exit_row = path_coords[len(path_coords)-1][1];
    exit_z = z_base + exit_row * maze_step;
    rotate([0, 0, exit_col * col_angle + col_angle/2])
    translate([inner_radius - groove_depth/2, 0, exit_z + (total_height - exit_z)/2])
        cube([groove_depth, groove_width, total_height - exit_z + groove_width], center=true);
}

// Inner part with nubs
module inner_part() {
    z_base = total_height/4;
    
    difference() {
        cylinder(r=inner_radius - 0.3, h=total_height - wall_thickness);
        translate([0, 0, wall_thickness])
            cylinder(r=inner_radius - wall_thickness - 0.3, h=total_height);
    }
    
    // Add nubs that follow the path
    for(i = [0:len(path_coords)-1]) {
        col = path_coords[i][0];
        row = path_coords[i][1];
        z = z_base + row * maze_step;
        ang = col * col_angle + col_angle/2;
        
        rotate([0, 0, ang])
        translate([inner_radius - 0.3, 0, z])
            sphere(r=groove_width/2 - 0.2, $fn=16);
    }
}

// Outer part with maze grooves
module outer_part() {
    difference() {
        // Outer shell
        difference() {
            cylinder(r=outer_radius, h=total_height);
            translate([0, 0, -0.1])
                cylinder(r=inner_radius, h=total_height + 0.2);
        }
        
        // Cut the maze grooves
        maze_grooves();
    }
    
    // Bottom cap
    cylinder(r=outer_radius, h=wall_thickness);
}

// Render based on display option
if(show_part == "inner" || show_part == "both") {
    color("SteelBlue")
    translate([0, 0, show_part == "both" ? explode_distance : 0])
        inner_part();
}

if(show_part == "outer" || show_part == "both") {
    color("Coral", 0.7)
        outer_part();
}

