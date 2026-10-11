// Kitchen design for Daniel's apartment
// Units: cm, same coordinates as the SketchUp model.
//
// Open in OpenSCAD, enable Design -> Automatic Reload and Preview, press F5.
// Tip: View -> "Show Edges" off, and Preferences -> 3D View -> "Tomorrow Night"
// for a dark background.

show_apartment = false;   // true = overlay the original SketchUp STL (ghost)
show_labels    = true;
wall_view_h    = 265.5; // real wall height; set e.g. 140 to cut walls and look in from above

// ---- Measured from danielsWohnung.stl ----
ceiling   = 265.5;

// room interior
room_x0   = -522;     // left end (no wall modelled in SketchUp here!)
room_x1   = -212.5;   // inner face of right wall
room_y0   = -143;     // inner face of bottom wall
room_y1   = 58;       // inner face of top (counter) wall

wall_t_top    = 18;   // 58 -> 76
wall_t_bottom = 18;   // -161 -> -143
wall_t_right  = 9.5;  // -212.5 -> -203

// doorway in the right wall
door_y0 = -96;
door_y1 = -27;
door_h  = 198;
door_t  = 4;          // leaf thickness
door_hinge_at_counter = false;  // false = hinges away from counter, latch on counter side
door_open = 90;       // how far the door is drawn open, in degrees

// column / duct in the top-right corner
col_x0 = -234;  col_x1 = room_x1;
col_y0 = -18;   col_y1 = room_y1;

// existing countertop
counter_x0 = room_x0;  counter_x1 = col_x0;
counter_y0 = -5.5;     counter_y1 = room_y1;
counter_z  = 88.5;     counter_t  = 3;

// ---- Colors (high contrast) ----
c_floor   = "#2b2b2b";
c_wall    = "#e8e2d0";
c_column  = "#b9b2a0";
c_counter = "#d08a3c";
c_label   = "#ffd400";
c_door    = "#4fa3e0";

// ---- Helpers ----
module box(x0, x1, y0, y1, z0, z1)
    translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);

module label(txt, x, y, rot = 0, size = 8)
    color(c_label) translate([x, y, 0.2]) rotate(rot)
        linear_extrude(0.5) text(txt, size = size, halign = "center", valign = "center");

// ---- Room ----
module room() {
    // floor
    color(c_floor) box(room_x0, room_x1 + wall_t_right, room_y0 - wall_t_bottom, room_y1 + wall_t_top, -2, 0);

    color(c_wall) {
        box(room_x0, room_x1 + wall_t_right, room_y1, room_y1 + wall_t_top, 0, wall_view_h);          // top wall
        box(room_x0, room_x1 + wall_t_right, room_y0 - wall_t_bottom, room_y0, 0, wall_view_h);       // bottom wall
        difference() {                                                                           // right wall + door
            box(room_x1, room_x1 + wall_t_right, room_y0 - wall_t_bottom, room_y1 + wall_t_top, 0, wall_view_h);
            box(room_x1 - 1, room_x1 + wall_t_right + 1, door_y0, door_y1, -1, door_h);
        }
    }
    color(c_column) box(col_x0, col_x1, col_y0, col_y1, 0, wall_view_h);
}

module existing_counter()
    color(c_counter) box(counter_x0, counter_x1, counter_y0, counter_y1, counter_z, counter_z + counter_t);

// door leaf swinging into the kitchen, plus its swing arc on the floor
module door() {
    w     = door_y1 - door_y0;
    dir   = door_hinge_at_counter ? -1 : 1;   // direction from hinge to latch when closed
    hinge = door_hinge_at_counter ? door_y1 : door_y0;

    color(c_door) translate([room_x1, hinge, 0]) rotate(dir * door_open)
        scale([1, dir, 1]) translate([-door_t, 0, 0]) cube([door_t, w, door_h]);

    color(c_door) translate([room_x1, hinge, 0.3])
        rotate(dir > 0 ? 90 : 270 - door_open)
            rotate_extrude(angle = door_open, $fn = 64)
                translate([w - 1.5, 0]) square([1.5, 0.5]);
}

module labels() {
    label(str(room_x1 - room_x0, " cm"), (room_x0 + room_x1) / 2, room_y0 + 15);
    label(str(room_y1 - room_y0, " cm"), room_x0 + 15, (room_y0 + room_y1) / 2, 90);
    label(str("counter ", counter_x1 - counter_x0, " x ", counter_y1 - counter_y0),
          (counter_x0 + counter_x1) / 2, counter_y0 - 12, 0, 7);
    label(str("door ", door_y1 - door_y0), room_x1 - 15, (door_y0 + door_y1) / 2, 90, 6);
}

// ---- Scene ----
room();
existing_counter();
door();
if (show_labels) labels();

if (show_apartment)
    %import("danielsWohnung.stl");

// ---- Kitchen (cabinets come here) ----
