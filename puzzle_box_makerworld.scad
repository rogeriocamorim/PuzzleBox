// Puzzle Box for MakerWorld
// Maze pattern on OUTSIDE of inner cylinder
// Uses BOSL2 library

include <BOSL2/std.scad>;

/* [Maze Path] */
// Paste the generated path string here
path_data = "UURRLUURRUULLUURR";

/* [Dimensions] */
inner_diameter = 30; // [20:60]
total_height = 60; // [40:100]
wall_thickness = 2; // [1.5:0.5:4]

/* [Maze Settings] */
maze_columns = 8; // [4:16]
maze_step = 4; // [2:0.5:8]
wall_height = 3; // [2:0.5:5]
wall_width = 2; // [1.5:0.5:4]

/* [Outer Shell] */
outer_sides = 8; // [0:Round, 6:Hexagon, 7:Heptagon, 8:Octagon, 10:Decagon]
outer_gap = 0.4; // [0.2:0.1:0.8]

/* [Display] */
show_part = "both"; // [inner, outer, both, assembled]
separation = 50; // [0:100]

/* [Hidden] */
$fn = 64;

// Parse path into moves
function parse_path(str, i=0) = 
    i >= len(str) ? [] :
    let(c = str[i], m = c=="U"||c=="u" ? [0,1] : c=="D"||c=="d" ? [0,-1] : c=="R"||c=="r" ? [1,0] : c=="L"||c=="l" ? [-1,0] : [0,0])
    concat([m], parse_path(str, i+1));

// Build coordinates from moves
function build_coords(moves, pos=[0,0], i=0) =
    i >= len(moves) ? [pos] :
    concat([pos], build_coords(moves, [(pos[0]+moves[i][0]+maze_columns)%maze_columns, pos[1]+moves[i][1]], i+1));

// Check if path connects two cells
function connected(coords, c1,r1, c2,r2) =
    len([for(i=[0:len(coords)-2]) if((coords[i]==[c1,r1] && coords[i+1]==[c2,r2]) || (coords[i]==[c2,r2] && coords[i+1]==[c1,r1])) 1]) > 0;

// Calculate maze data
moves = parse_path(path_data);
path_coords = build_coords(moves);
maze_rows = max([for(p=path_coords) p[1]]) + 2;
inner_r = inner_diameter/2;
maze_r = inner_r + wall_thickness;
outer_r = maze_r + wall_height + outer_gap + wall_thickness;
col_ang = 360/maze_columns;
maze_height = maze_rows * maze_step;
base_height = (total_height - maze_height) / 2;

echo(str("Path: ", len(path_coords), " cells"));
echo(str("Maze: ", maze_columns, " cols x ", maze_rows, " rows"));

// INNER PART - cylinder with maze walls on OUTSIDE
module inner_part() {
    // Base cylinder
    difference() {
        cylinder(r=maze_r, h=total_height);
        translate([0, 0, wall_thickness])
            cylinder(r=inner_r, h=total_height);
    }
    
    // Maze walls on outside surface
    maze_walls();
    
    // Top and bottom rings
    translate([0, 0, base_height - wall_width/2])
        ring(maze_r, wall_height, wall_width);
    translate([0, 0, base_height + maze_height])
        ring(maze_r, wall_height, wall_width);
}

module ring(r, h, w) {
    difference() {
        cylinder(r=r+h, h=w);
        translate([0, 0, -0.1])
            cylinder(r=r, h=w+0.2);
    }
}

module maze_walls() {
    z0 = base_height;
    
    for(row = [0:maze_rows-1]) {
        z = z0 + row * maze_step;
        
        for(col = [0:maze_columns-1]) {
            ang = col * col_ang;
            next_col = (col + 1) % maze_columns;
            
            // Horizontal wall (blocks movement around)
            h_open = connected(path_coords, col, row, next_col, row);
            if(!h_open) {
                rotate([0, 0, ang + col_ang])
                translate([maze_r + wall_height/2, 0, z + maze_step/2])
                    cube([wall_height, wall_width, maze_step], center=true);
            }
            
            // Vertical wall (blocks movement up/down) - arc segment
            v_open = connected(path_coords, col, row, col, row+1);
            if(!v_open && row < maze_rows - 1) {
                rotate([0, 0, ang])
                translate([0, 0, z + maze_step])
                linear_extrude(height=wall_width, center=true)
                difference() {
                    circle(r=maze_r + wall_height);
                    circle(r=maze_r);
                    rotate([0, 0, col_ang])
                        translate([-outer_r*2, 0]) square([outer_r*4, outer_r*4]);
                    translate([-outer_r*2, -outer_r*4]) square([outer_r*4, outer_r*4]);
                }
            }
        }
    }
    
    // Entry opening at bottom
    entry_col = path_coords[0][0];
    rotate([0, 0, entry_col * col_ang])
    translate([0, 0, z0/2])
    linear_extrude(height=base_height + maze_step, center=true)
    difference() {
        circle(r=maze_r + wall_height);
        circle(r=maze_r);
        rotate([0, 0, col_ang])
            translate([-outer_r*2, 0]) square([outer_r*4, outer_r*4]);
        translate([-outer_r*2, -outer_r*4]) square([outer_r*4, outer_r*4]);
    }
    
    // Exit opening at top  
    exit_col = path_coords[len(path_coords)-1][0];
    exit_z = z0 + (maze_rows-1) * maze_step;
    rotate([0, 0, exit_col * col_ang])
    translate([0, 0, exit_z + (total_height - exit_z)/2])
    linear_extrude(height=total_height - exit_z + wall_width, center=true)
    difference() {
        circle(r=maze_r + wall_height);
        circle(r=maze_r);
        rotate([0, 0, col_ang])
            translate([-outer_r*2, 0]) square([outer_r*4, outer_r*4]);
        translate([-outer_r*2, -outer_r*4]) square([outer_r*4, outer_r*4]);
    }
}

// OUTER PART - shell with nub inside
module outer_part() {
    nub_r = maze_r + wall_height/2 + outer_gap;
    
    difference() {
        // Outer shell (polygon or round)
        if(outer_sides == 0) {
            cylinder(r=outer_r, h=total_height);
        } else {
            cylinder(r=outer_r/cos(180/outer_sides), h=total_height, $fn=outer_sides);
        }
        
        // Hollow inside
        translate([0, 0, wall_thickness])
            cylinder(r=maze_r + wall_height + outer_gap, h=total_height);
    }
    
    // Nub that follows the maze
    translate([nub_r, 0, base_height + maze_step/2])
        sphere(r=wall_width/2, $fn=16);
}

// Display parts
if(show_part == "inner" || show_part == "both") {
    color("Gold")
    translate([show_part == "both" ? -separation/2 : 0, 0, 0])
        inner_part();
}

if(show_part == "outer" || show_part == "both") {
    color("OliveDrab", 0.8)
    translate([show_part == "both" ? separation/2 : 0, 0, 0])
        outer_part();
}

if(show_part == "assembled") {
    color("Gold") inner_part();
    color("OliveDrab", 0.5) outer_part();
}
