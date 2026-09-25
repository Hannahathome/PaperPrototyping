module _local_draw_edge(p1, p2, r) {
    v = p2 - p1;
    d = norm(v);
    b = acos(v[2] / d);
    a = atan2(v[1], v[0]);
    translate(p1)
    rotate([0, b, a])
    cylinder(h = d, r = r);
}

// Vertical wall strut: a full cylinder whose top `flap_length` tapers
// linearly into a half-circle, forming an angled wedge flap at the tip.
// The flap is then sheared flush by the top trimming slice in the export.
// Reads the global `flap_length` (written near the top of the exported file).
module _local_draw_half_edge(p1, p2, r, pillar_rot = 0) {
    v = p2 - p1;
    d = norm(v);
    b = acos(v[2] / d);
    a = atan2(v[1], v[0]);

    extended_height = d + r;
    height_80 = extended_height - flap_length;   // where the taper begins
    height_20 = flap_length;

    translate(p1)
    rotate([0, b, a])
    rotate([0, 0, pillar_rot])
    difference() {
        // Core full-thickness strut
        cylinder(h = extended_height, r = r);

        // Linear wedge cutter over the top flap_length: stays outside the
        // radius at the taper start, sweeps to the centre line (Y=0) at the tip.
        translate([0, 0, height_80]) {
            hull() {
                translate([-r*2, r, 0])
                    cube([r*4, r*2, 0.01]);
                translate([-r*2, 0, height_20])
                    cube([r*4, r*2, 0.01]);
            }
            // Clean-up block past the tip so no ghost fragments remain
            translate([-r*2, 0, height_20 - 0.01])
                cube([r*4, r*2, r * 2]);
        }
    }
}