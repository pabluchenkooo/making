// Kitchen design for Daniel's apartment
// Units: cm, same coordinates as the SketchUp model.
//
// Open in OpenSCAD, enable Design -> Automatic Reload and Preview, press F5.
// Tip: View -> "Show Edges" off, and Preferences -> 3D View -> "Tomorrow Night"
// for a dark background.
//
// Layout is defined by the two lists COUNTER_RUN and OPPOSITE_RUN below.
// Reorder or resize entries there; everything else follows.

show_apartment  = false;  // true = overlay the original SketchUp STL (ghost)
show_old_counter = false; // true = show the current countertop as a ghost
show_labels     = true;
show_uppers     = true;   // wall cabinets + shelf above the counter
wall_view_h     = 265.5;  // real wall height; set e.g. 140 to cut walls and look in from above

// =====================================================================
// Room, measured from danielsWohnung.stl
// =====================================================================
ceiling   = 265.5;

room_x0   = -522;     // window end (window not modelled)
room_x1   = -212.5;   // inner face of door wall
room_y0   = -143;     // inner face of opposite wall
room_y1   = 58;       // inner face of counter wall

wall_t_top    = 18;
wall_t_bottom = 18;
wall_t_right  = 9.5;

// doorway in the right wall
door_y0 = -96;
door_y1 = -27;
door_h  = 198;
door_t  = 4;
door_hinge_at_counter = false;  // false = hinges away from counter, latch on counter side
door_open = 90;                 // degrees the door is drawn open

// column / duct in the corner at the end of the counter
col_x0 = -234;  col_x1 = room_x1;
col_y0 = -18;   col_y1 = room_y1;

// current countertop (for reference only)
old_counter = [room_x0, col_x0, -5.5, room_y1, 88.5, 91.5];

// =====================================================================
// Kitchen
// =====================================================================
plinth_h   = 10;      // toe kick height
plinth_in  = 5;       // toe kick recess
front_t    = 2;       // door/drawer front thickness
gap        = 0.3;     // gap between fronts

counter_top = 91.5;   // top of worktop (same as now)
counter_t   = 3;
counter_d   = 63.5;   // worktop depth from wall
base_d      = 58;     // carcass depth (+ front = 60)
base_top    = counter_top - counter_t;

// Counter wall, from the window end towards the column. [type, width]
// Total available: 288 cm (window end -> column).
COUNTER_RUN = [
    ["drawers",    38],
    ["oven",       60],   // existing oven, hob on top
    ["sink",       60],
    ["dishwasher", 60],
    ["washer",     70],
];

// Opposite wall, from the window end towards the door. [type, width, depth]
// Keep anything next to the door shallow (<= 40): the open door leaf
// sits ~47 cm from this wall.
// Types: "fridge", "sideboard" (low drawers + floating shelves),
//        "pantry" (floor-to-ceiling shelves), "shelves", "empty".
OPPOSITE_RUN = [
    ["fridge",     60,   65],
    ["sideboard", 180,   35],
    ["shelves",    69.5, 25],   // behind the door, up to the ceiling
];

// shelf heights of the tall shelf unit; 150 and 188 line up with the floating shelves
tall_shelves_z = [10, 41, 76, 112, 150, 188, 226];
tall_shelves_h = ceiling;

sideboard_drawer_rows = 2;
float_shelves = [150, 188];   // heights of the floating shelves above the sideboard
float_shelf_d = 25;

pantry_gap = 55;      // clear height above the pantry worktop (coffee station)
coffee_col = 1;       // sideboard/pantry column the coffee machine stands in (0 = window end)
coffee     = [32, 34, 40];   // Sage Barista Express, w x d x h

fridge_h   = 185;
fridge_top_cabinet = false;  // cabinet above the fridge
tall_h     = 250;     // top of tall units / wall cabinets

// wall cabinets above the counter
upper_z0   = 155;
upper_d    = 35;
upper_doors = 4;
shelf_z    = 135;     // floating shelf under the wall cabinets
shelf_d    = 22;

// =====================================================================
// Colors
// =====================================================================
c_floor   = "#2b2b2b";
c_wall    = "#8d9096";
c_column  = "#a3a6ab";
c_label   = "#ffd400";
c_door    = "#4fa3e0";
c_oak     = "#d2a96f";
c_oak_dk  = "#9b7647";
c_stone   = "#efebe3";
c_black   = "#1b1b1b";
c_steel   = "#b4b8bc";
c_white   = "#f6f6f4";
c_glass   = "#2a2f33";

// =====================================================================
// Helpers
// =====================================================================
// Export support: with export_part set to one color, only parts in that color are drawn.
// Used by export.sh to write one STL per material for Blender.
export_part = "";
module paint(c) {
    if (export_part == "") color(c) children();
    else if (c == export_part) children();
}

module box(x0, x1, y0, y1, z0, z1)
    translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);

module label(txt, x, y, rot = 0, size = 6)
    paint(c_label) translate([x, y, 0.2]) rotate(rot)
        linear_extrude(0.5) text(txt, size = size, halign = "center", valign = "center");

// sum of widths of the first n entries
function run_x(run, n) = n <= 0 ? 0 : run[n - 1][1] + run_x(run, n - 1);

// Units are drawn in local coordinates: x = 0..w along the wall,
// y = 0 is the front face, y = d is the wall, fronts stick out to y = -front_t.

// a door/drawer front with a black bar handle near its top (or side)
module front(x0, z0, w, h, handle = "top") {
    paint(c_oak) translate([x0 + gap, -front_t, z0 + gap]) cube([w - 2 * gap, front_t, h - 2 * gap]);
    hw = min(w - 10, 16);
    paint(c_black)
        if (handle == "top")
            translate([x0 + (w - hw) / 2, -front_t - 1.5, z0 + h - 6]) cube([hw, 1.5, 1.2]);
        else if (handle == "side")
            translate([x0 + w - 5, -front_t - 1.5, z0 + h / 2 - 15]) cube([1.2, 1.5, 30]);
}

module carcass(w, d, z0, z1) {
    paint(c_oak_dk) translate([0, 0, z0]) cube([w, d, z1 - z0]);
}

module plinth(w, d) paint(c_black) translate([0, plinth_in, 0]) cube([w, d - plinth_in, plinth_h]);

// =====================================================================
// Base units (counter wall)
// =====================================================================
module base_unit(type, w) {
    d = base_d;
    H = base_top - plinth_h;

    if (type == "washer") {
        // freestanding, no plinth
        paint(c_white) translate([0.5, 0, 0]) cube([w - 1, d, 85]);
        paint(c_glass) translate([w / 2, -0.1, 45]) rotate([90, 0, 0]) cylinder(r = 17, h = 1, $fn = 48);
        paint(c_steel) translate([w / 2, -0.2, 45]) rotate([90, 0, 0])
            difference() { cylinder(r = 20, h = 1, $fn = 48); translate([0, 0, -1]) cylinder(r = 17, h = 3, $fn = 48); }
        paint(c_steel) translate([3, -0.5, 75]) cube([20, 0.5, 6]);
    } else {
        plinth(w, d);
        carcass(w, d, plinth_h, base_top);

        if (type == "drawers") {
            hs = [H * 0.24, H * 0.34, H * 0.42];
            front(0, plinth_h + hs[2] + hs[1], w, hs[0]);
            front(0, plinth_h + hs[2], w, hs[1]);
            front(0, plinth_h, w, hs[2]);
        } else if (type == "door") {
            front(0, plinth_h, w, H, "side");
        } else if (type == "dishwasher") {
            front(0, plinth_h, w, H);           // integrated: oak panel
        } else if (type == "sink") {
            front(0, plinth_h, w / 2, H, "side");
            front(w / 2, plinth_h, w / 2, H, "side");
        } else if (type == "oven") {
            dh = H - 60;                         // drawer under the oven
            front(0, plinth_h, w, dh);
            paint(c_steel) translate([gap, -front_t, plinth_h + dh + gap]) cube([w - 2 * gap, front_t, 60 - 2 * gap]);
            paint(c_glass) translate([5, -front_t - 0.2, plinth_h + dh + 8]) cube([w - 10, 0.5, 38]);
            paint(c_black) translate([5, -front_t - 2, plinth_h + dh + 50]) cube([w - 10, 1.5, 1.5]);
        }
    }

    // things on top of the worktop
    if (type == "sink") {
        paint(c_steel) translate([(w - 50) / 2, 4, counter_top]) cube([50, 40, 0.3]);
        paint(c_black) {
            translate([w / 2, 50, counter_top]) cylinder(r = 1.5, h = 32, $fn = 16);
            translate([w / 2, 50, counter_top + 30]) rotate([90, 0, 0]) cylinder(r = 1.2, h = 22, $fn = 16);
        }
    }
    if (type == "oven") {
        paint(c_black) translate([(w - 56) / 2, 3, counter_top]) cube([56, 50, 0.4]);
        paint(c_steel) for (p = [[15, 15, 8], [41, 15, 7], [15, 40, 7], [41, 40, 9]])
            translate([(w - 56) / 2 + p[0], 3 + p[1], counter_top + 0.4]) cylinder(r = p[2], h = 0.1, $fn = 32);
    }
}

// =====================================================================
// Tall / opposite wall units
// =====================================================================
// first_gap: height of the lowest opening (defaults to pitch)
module open_shelving(w, d, z0, z1, pitch, dividers = 1, first_gap = 0) {
    t = 2;
    g = first_gap > 0 ? first_gap : pitch;
    n = max(1, round((z1 - z0 - g) / pitch));   // stretch pitch so the top opening isn't a sliver
    p = (z1 - t - (z0 + g)) / n;
    paint(c_oak_dk) translate([0, d - 1, z0]) cube([w, 1, z1 - z0]);          // back
    paint(c_oak) {
        for (x = [0 : w / dividers : w - 0.01]) translate([x, 0, z0]) cube([t, d, z1 - z0]);
        translate([w - t, 0, z0]) cube([t, d, z1 - z0]);
        translate([0, 0, z0]) cube([w, d, t]);
        for (i = [0 : n - 1]) translate([0, 0, z0 + g + i * p]) cube([w, d, t]);
        translate([0, 0, z1 - t]) cube([w, d, t]);
    }
}

// Sage Barista Express: steel body, bean hopper on top, portafilter in front
module coffee_machine() {
    w = coffee[0]; d = coffee[1]; h = coffee[2];
    paint(c_steel) translate([0, 0.5, 0]) cube([w, d - 0.5, h - 8]);
    paint(c_glass) translate([w * 0.55, d * 0.3, h - 8]) cylinder(r1 = 6, r2 = 7.5, h = 8, $fn = 32);
    paint(c_glass) translate([3, -0.1, 5]) cube([w - 6, 0.5, 8]);                // drip tray
    paint(c_black) translate([w * 0.3, -14, 20]) cube([3, 14, 2.5]);             // portafilter handle
}

module tall_unit(type, w, d) {
    if (type == "pantry") {
        cols = max(1, round(w / 60));
        cw = w / cols;
        plinth(w, d);
        carcass(w, d, plinth_h, 88);
        rh = (88 - plinth_h) / 3;
        for (c = [0 : cols - 1], r = [0 : 2]) front(c * cw, plinth_h + r * rh, cw, rh);
        paint(c_stone) translate([0, -3, 88]) cube([w, d + 3, 3]);           // small worktop
        open_shelving(w, d, 91, tall_h, 32, cols, pantry_gap);
        translate([coffee_col * cw + (cw - coffee[0]) / 2, 0, 91]) coffee_machine();
    } else if (type == "sideboard") {
        cols = max(1, round(w / 60));
        cw = w / cols;
        plinth(w, d);
        carcass(w, d, plinth_h, 88);
        rh = (88 - plinth_h) / sideboard_drawer_rows;
        for (c = [0 : cols - 1], r = [0 : sideboard_drawer_rows - 1]) front(c * cw, plinth_h + r * rh, cw, rh);
        paint(c_stone) translate([0, -3, 88]) cube([w, d + 3, 3]);
        translate([coffee_col * cw + (cw - coffee[0]) / 2, 0, 91]) coffee_machine();
        paint(c_oak) for (z = float_shelves) translate([0, d - float_shelf_d, z]) cube([w, float_shelf_d, 3]);
    } else if (type == "shelves") {
        t = 2;
        plinth(w, d);
        paint(c_oak_dk) translate([0, d - 1, plinth_h]) cube([w, 1, tall_shelves_h - plinth_h]);   // back
        paint(c_oak) {
            for (x = [0, w - t]) translate([x, 0, 0]) cube([t, d, tall_shelves_h]);
            for (z = tall_shelves_z) translate([0, 0, z]) cube([w, d, t]);
            translate([0, 0, tall_shelves_h - t]) cube([w, d, t]);
        }
    } else if (type == "fridge") {
        paint(c_white) translate([0.5, 0, 0]) cube([w - 1, d, fridge_h]);
        paint(c_black) translate([0.5, -0.1, 65]) cube([w - 1, 0.2, 0.6]);  // freezer split
        paint(c_steel) {
            translate([w - 6, -3, 20]) cube([1.5, 3, 35]);
            translate([w - 6, -3, 85]) cube([1.5, 3, 60]);
        }
        if (fridge_top_cabinet) translate([0, d - 60, 0]) {
            carcass(w, 60, fridge_h + 2, tall_h);
            front(0, fridge_h + 2, w, tall_h - fridge_h - 2);
        }
    }
}

// =====================================================================
// Wall cabinets above the counter
// =====================================================================
module uppers() {
    w = col_x0 - room_x0;
    dw = w / upper_doors;
    translate([room_x0, room_y1 - upper_d, 0]) {
        carcass(w, upper_d, upper_z0, tall_h);
        for (i = [0 : upper_doors - 1]) front(i * dw, upper_z0, dw, tall_h - upper_z0, "none");
    }
    paint(c_oak) box(room_x0, col_x0, room_y1 - shelf_d, room_y1, shelf_z, shelf_z + 3);
}

// =====================================================================
// Room and door
// =====================================================================
module room() {
    paint(c_floor) box(room_x0, room_x1 + wall_t_right, room_y0 - wall_t_bottom, room_y1 + wall_t_top, -2, 0);
    paint(c_wall) {
        box(room_x0, room_x1 + wall_t_right, room_y1, room_y1 + wall_t_top, 0, wall_view_h);
        box(room_x0, room_x1 + wall_t_right, room_y0 - wall_t_bottom, room_y0, 0, wall_view_h);
        difference() {
            box(room_x1, room_x1 + wall_t_right, room_y0 - wall_t_bottom, room_y1 + wall_t_top, 0, wall_view_h);
            box(room_x1 - 1, room_x1 + wall_t_right + 1, door_y0, door_y1, -1, door_h);
        }
    }
    paint(c_column) box(col_x0, col_x1, col_y0, col_y1, 0, wall_view_h);
}

module door() {
    w     = door_y1 - door_y0;
    dir   = door_hinge_at_counter ? -1 : 1;
    hinge = door_hinge_at_counter ? door_y1 : door_y0;

    paint(c_door) translate([room_x1, hinge, 0]) rotate(dir * door_open)
        scale([1, dir, 1]) translate([-door_t, 0, 0]) cube([door_t, w, door_h]);

    if (show_labels) paint(c_door) translate([room_x1, hinge, 0.3])   // swing arc
        rotate(dir > 0 ? 90 : 270 - door_open)
            rotate_extrude(angle = door_open, $fn = 64)
                translate([w - 1.5, 0]) square([1.5, 0.5]);
}

// =====================================================================
// Scene
// =====================================================================
room();
door();

// counter wall
for (i = [0 : len(COUNTER_RUN) - 1]) {
    u = COUNTER_RUN[i];
    translate([room_x0 + run_x(COUNTER_RUN, i), room_y1 - base_d, 0]) base_unit(u[0], u[1]);
}
paint(c_stone) box(room_x0, col_x0, room_y1 - counter_d, room_y1, base_top, counter_top);
if (show_uppers) uppers();

// opposite wall (rotated so fronts face the counter)
for (i = [0 : len(OPPOSITE_RUN) - 1]) {
    u = OPPOSITE_RUN[i];
    translate([room_x0 + run_x(OPPOSITE_RUN, i) + u[1], room_y0 + u[2], 0]) rotate(180)
        tall_unit(u[0], u[1], u[2]);
}

if (show_labels) {
    for (i = [0 : len(COUNTER_RUN) - 1]) {
        u = COUNTER_RUN[i];
        label(str(u[0], " ", u[1]), room_x0 + run_x(COUNTER_RUN, i) + u[1] / 2, room_y1 - counter_d - 8, 0, 4);
    }
    for (i = [0 : len(OPPOSITE_RUN) - 1]) {
        u = OPPOSITE_RUN[i];
        x = room_x0 + run_x(OPPOSITE_RUN, i) + u[1] / 2;
        label(str(u[0], " ", u[1]), x, room_y0 + u[2] + 8, 0, 4);
        label(str("aisle ", room_y1 - counter_d - room_y0 - u[2] - (u[2] > 0 ? front_t : 0)), x, room_y0 + u[2] + 16, 0, 4);
    }
    // leftover space per wall; negative = doesn't fit
    label(str("left over - counter: ", col_x0 - room_x0 - run_x(COUNTER_RUN, len(COUNTER_RUN)),
              "   opposite: ", room_x1 - room_x0 - run_x(OPPOSITE_RUN, len(OPPOSITE_RUN))),
          (room_x0 + room_x1) / 2, (room_y0 + room_y1) / 2 + 10, 0, 4);
}

if (show_old_counter)
    %box(old_counter[0], old_counter[1], old_counter[2], old_counter[3], old_counter[4], old_counter[5]);

if (show_apartment)
    %import("danielsWohnung.stl");
