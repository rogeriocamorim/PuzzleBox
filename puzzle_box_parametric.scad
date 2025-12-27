// ============================================================
// PARAMETRIC PUZZLE BOX FOR MAKERWORLD
// ============================================================
// Proper maze with visible grooves on OUTER surface
// Based on RevK's PuzzleBox concept
// ============================================================

include <BOSL2/std.scad>

/* [═══ SIZE ═══] */
core_diameter = 30; // [15:1:60]
core_height = 50; // [20:1:100]  
num_parts = 2; // [2:1:4]

/* [═══ SHAPE ═══] */
outer_sides = 7; // [0:1:12]
edge_round = 2; // [0:0.5:5]

/* [═══ MAZE ═══] */
maze_thickness = 2.0; // [1.5:0.1:3]
maze_step = 3; // [2:0.5:5]
helix = 2; // [0:1:4]
maze_seed = 42; // [1:1:9999]
maze_complexity = 5; // [-10:1:10]

/* [═══ STRUCTURE ═══] */
wall_thickness = 1.2; // [0.8:0.1:2]
base_height = 10; // [5:1:20]
base_thickness = 1.6; // [1:0.2:3]

/* [═══ CLEARANCE ═══] */
clearance = 0.4; // [0.2:0.05:0.6]
base_gap = 0.4; // [0.2:0.05:0.6]
resin_mode = false;

/* [═══ TEXT ═══] */
text_end = "";
text_depth = 0.5; // [0.2:0.1:1]

/* [═══ VIEW ═══] */
show_part = 0; // [0:1:4]
$fn = 48; // [24:8:96]

// ============================================================
clr = resin_mode ? clearance/2 : clearance;
bgap = resin_mode ? base_gap/2 : base_gap;

// ============================================================
// MAZE PATH GENERATION
// ============================================================

function make_path(cols, rows, seed) = 
    _make_path_iter(cols, rows, [[floor(rands(0,cols-0.1,1,seed)[0]), 0]], seed, 0);

function _make_path_iter(cols, rows, path, seed, iter) =
    let(p = path[len(path)-1], col = p[0], row = p[1])
    (row >= rows-1 || iter > rows*4) ? path :
    let(
        r = rands(0, 100, 1, seed + iter)[0],
        // Weighted random: mostly up, sometimes sideways
        ncol = r < 15 ? max(0,col-1) : r < 30 ? min(cols-1,col+1) : col,
        nrow = (r >= 30 || iter % 2 == 0) ? min(rows-1, row+1) : row,
        npos = [ncol, nrow]
    )
    _make_path_iter(cols, rows, concat(path, [npos]), seed+1, iter+1);

function on_path(path, c, r) = len([for(p=path) if(p[0]==c && p[1]==r) 1]) > 0;
function path_connects(path, c1,r1, c2,r2) =
    let(
        i1 = [for(i=[0:len(path)-1]) if(path[i][0]==c1 && path[i][1]==r1) i],
        i2 = [for(i=[0:len(path)-1]) if(path[i][0]==c2 && path[i][1]==r2) i]
    ) (len(i1)>0 && len(i2)>0) ? (abs(i1[0]-i2[0]) <= 1) : false;

// ============================================================
// MAZE WALL MODULE - Creates raised walls, gaps form the maze
// ============================================================

module maze_walls(r, h, z0, seed) {
    cols = max(12, floor(2*PI*r / maze_step));
    cols_adj = helix > 0 ? floor(cols/helix)*helix : cols;
    rows = max(6, floor(h / maze_step));
    
    col_ang = 360 / cols_adj;
    helix_ang = helix > 0 ? 360*helix/rows : 0;
    
    path = make_path(cols_adj, rows, seed);
    echo(str("Maze path length: ", len(path)));
    
    // Create walls - gaps between walls form the maze channels
    for (row = [0:rows]) {
        z = z0 + row * maze_step;
        
        for (col = [0:cols_adj-1]) {
            ang = col * col_ang + row * helix_ang / cols_adj;
            next_col = (col + 1) % cols_adj;
            
            // Horizontal wall (blocks movement around circumference)
            h_blocked = !path_connects(path, col, row, next_col, row);
            if (h_blocked && row > 0 && row < rows) {
                rotate([0, 0, ang + col_ang*0.9])
                translate([r, 0, z])
                    cube([maze_thickness*1.2, maze_thickness, maze_step*0.9], center=true);
            }
            
            // Vertical wall (blocks movement up/down)
            v_blocked = !path_connects(path, col, row, col, row+1);
            if (v_blocked && row < rows-1) {
                rotate([0, 0, ang + col_ang*0.45])
                translate([r, 0, z + maze_step/2])
                rotate([0, 0, 0])
                rotate_extrude(angle=col_ang*0.88, $fn=12)
                translate([0, 0, 0])
                    square([maze_thickness, maze_thickness], center=true);
            }
        }
    }
    
    // Outer ring walls at top and bottom
    translate([0, 0, z0 - maze_step/4])
        difference() {
            cylinder(r=r+maze_thickness/2, h=maze_step/2);
            translate([0,0,-0.1])
            cylinder(r=r-maze_thickness/2, h=maze_step/2+0.2);
            // Entry gap
            rotate([0, 0, path[0][0] * col_ang])
            translate([r, 0, 0])
                cube([maze_thickness*3, maze_thickness*2, maze_step], center=true);
        }
        
    translate([0, 0, z0 + h])
        difference() {
            cylinder(r=r+maze_thickness/2, h=maze_step/2);
            translate([0,0,-0.1])
            cylinder(r=r-maze_thickness/2, h=maze_step/2+0.2);
            // Exit gap
            rotate([0, 0, path[len(path)-1][0] * col_ang + (rows-1)*helix_ang/cols_adj])
            translate([r, 0, 0])
                cube([maze_thickness*3, maze_thickness*2, maze_step], center=true);
        }
}

// ============================================================
// NUBS - Ride in the maze channels
// ============================================================

module nubs(r, z, n) {
    for (i = [0:n-1]) {
        rotate([0, 0, i*360/n])
        translate([r, 0, z])
        sphere(d=maze_thickness*0.8, $fn=16);
    }
}

// ============================================================
// OUTER SHELL
// ============================================================

module shell(h, r, rnd=true) {
    rv = (edge_round>0.5 && rnd) ? min(edge_round, h/4, r/4) : 0;
    if (outer_sides == 0) {
        if (rv > 0.5) minkowski() { cylinder(h=h-rv*2, r=r-rv); sphere(r=rv); }
        else cylinder(h=h, r=r);
    } else {
        rp = r / cos(180/outer_sides);
        if (rv > 0.5) minkowski() { cylinder(h=h-rv*2, r=rp-rv, $fn=outer_sides); sphere(r=rv); }
        else cylinder(h=h, r=rp, $fn=outer_sides);
    }
}

// ============================================================
// INNER PART - Has nubs and maze walls on outside
// ============================================================

module inner_part(pn) {
    r_core = core_diameter/2;
    r_wall = r_core + wall_thickness;
    r_maze = r_wall + maze_thickness;
    h = core_height + base_thickness;
    r_base = r_maze + clr + wall_thickness;
    maze_h = h - base_height - maze_step*2;
    
    color("#388E3C")
    union() {
        difference() {
            union() {
                // Main body with maze surface
                cylinder(h=h, r=r_wall);
                // Base
                cylinder(h=base_height, r=r_base);
            }
            // Hollow core
            translate([0, 0, base_thickness])
                cylinder(h=h+1, r=r_core);
        }
        
        // MAZE WALLS on outside surface
        maze_walls(r_wall + maze_thickness/2, maze_h, base_height + maze_step, maze_seed);
        
        // Nubs that ride in the maze of the outer part
        nubs(r_maze - maze_thickness*0.3, h - maze_step, max(2, helix));
    }
}

// ============================================================
// OUTER PART - Hollow shell with maze grooves inside
// ============================================================

module outer_part(pn) {
    r_core = core_diameter/2;
    r_prev_maze = r_core + wall_thickness + maze_thickness;
    r_inner = r_prev_maze + clr;
    r_outer = r_inner + wall_thickness + maze_thickness;
    
    h = core_height + base_thickness + (pn-1)*(base_thickness + bgap);
    
    is_last = (pn == num_parts);
    colors = ["#388E3C", "#FBC02D", "#F57C00", "#1976D2"];
    
    color(colors[(pn-1)%4])
    difference() {
        // Outer shape
        if (is_last) {
            shell(h, r_outer, true);
        } else {
            cylinder(h=h, r=r_outer);
        }
        
        // Inner hollow - leaves wall for maze
        translate([0, 0, base_thickness])
            cylinder(h=h+1, r=r_inner);
        
        // Text on lid
        if (is_last && len(text_end) > 0) {
            translate([0, 0, -0.01])
            linear_extrude(text_depth+0.02)
            mirror([1,0,0])
                text(text_end, size=r_outer*0.4, halign="center", valign="center",
                     font="Liberation Sans:style=Bold");
        }
    }
}

// ============================================================
// MAIN
// ============================================================

module make_part(p) {
    if (p == 1) inner_part(p);
    else outer_part(p);
}

spacing = core_diameter * 2.5 + 20;

if (show_part == 0) {
    for (p = [1:num_parts])
        translate([(p-1-(num_parts-1)/2)*spacing, 0, 0])
            make_part(p);
} else {
    make_part(min(show_part, num_parts));
}

if ($preview) {
    color("white", 0.6)
    translate([0, -core_diameter-30, 0])
    linear_extrude(0.1)
        text(str("Seed: ", maze_seed), size=5, halign="center");
}
