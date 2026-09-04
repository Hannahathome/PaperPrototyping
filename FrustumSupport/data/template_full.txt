// Frustum cage (drawn once) + per-rig internal supports (drawn once per rig).

module frustumCage(
    frustum_nside, frustum_bottom_radius, frustum_top_radius, frustum_height, edge_radius
){
    $fn = 16;
    vertex_radius = edge_radius;
    bottom_radius = frustum_bottom_radius - edge_radius;
    top_radius    = frustum_top_radius - edge_radius;
    height        = frustum_height - (2 * vertex_radius);
    vertices = [
        for (i = [0 : frustum_nside - 1])
            let(angle = i * 360 / frustum_nside)
            [bottom_radius * cos(angle), bottom_radius * sin(angle), -height/2],

        for (i = [0 : frustum_nside - 1])
            let(angle = i * 360 / frustum_nside)
            [top_radius * cos(angle), top_radius * sin(angle), height/2]
    ];
    bottom_cross_spokes = [
        for (i = [0 : frustum_nside - 1]) let(
            p1 = vertices[i],
            p2 = vertices[(i + 1) % frustum_nside],
            midpoint = (p1 + p2) / 2,
            center   = [0, 0, -height/2]
        )
        [midpoint, center]
    ];
    union() {
        for (i = [0 : frustum_nside - 1]) {
            translate(vertices[i]) sphere(r = vertex_radius);
        }
        // Bottom perimeter ring
        for (i = [0 : frustum_nside - 1]) {
            _local_draw_edge(vertices[i], vertices[(i + 1) % frustum_nside], edge_radius);
        }
        // Vertical wall struts (wedged flap tips, sheared flush by the top slice)
        for (i = [0 : frustum_nside - 1]) {
            _local_draw_half_edge(vertices[i], vertices[i + frustum_nside], edge_radius, 0);
        }
        for (spoke = bottom_cross_spokes) {
            _local_draw_edge(spoke[0], spoke[1], edge_radius);
        }
    }
}

module rigSupport(
    frustum_height, edge_radius,
    cuboid_width, cuboid_depth, cuboid_height,
    cuboid_offset_x, cuboid_offset_y, cuboid_offset_z, cuboid_rotation,
    strut_mode = 1, strut_spacing = 15
){
    $fn = 16;
    vertex_radius   = edge_radius;
    height          = frustum_height - (2 * vertex_radius);
    hx              = cuboid_width / 2;
    hy              = cuboid_depth / 2;
    z_bottom        = -height/2;
    z_support_start = z_bottom;
    z_cuboid_bot    = z_bottom + cuboid_offset_z - edge_radius*2;
    z_cuboid_top    = z_cuboid_bot + cuboid_height;
    center_start = [cuboid_offset_x, cuboid_offset_y, z_support_start];
    center_end   = [cuboid_offset_x, cuboid_offset_y, z_cuboid_bot];
    half_sp = strut_spacing / 2;
    // strut_mode 2 = two posts per face (spread by strut_spacing); 1 = one post per face
    supports = strut_mode == 2 ? [
        // +Y face: two posts spread along X
        [[cuboid_offset_x - half_sp, cuboid_offset_y + hy + edge_radius, z_support_start],
         [cuboid_offset_x - half_sp, cuboid_offset_y + hy + edge_radius, z_cuboid_top]],
        [[cuboid_offset_x + half_sp, cuboid_offset_y + hy + edge_radius, z_support_start],
         [cuboid_offset_x + half_sp, cuboid_offset_y + hy + edge_radius, z_cuboid_top]],
        // -Y face: two posts spread along X
        [[cuboid_offset_x - half_sp, cuboid_offset_y - hy - edge_radius, z_support_start],
         [cuboid_offset_x - half_sp, cuboid_offset_y - hy - edge_radius, z_cuboid_top]],
        [[cuboid_offset_x + half_sp, cuboid_offset_y - hy - edge_radius, z_support_start],
         [cuboid_offset_x + half_sp, cuboid_offset_y - hy - edge_radius, z_cuboid_top]],
        // +X face: two posts spread along Y
        [[cuboid_offset_x + hx + edge_radius, cuboid_offset_y - half_sp, z_support_start],
         [cuboid_offset_x + hx + edge_radius, cuboid_offset_y - half_sp, z_cuboid_top]],
        [[cuboid_offset_x + hx + edge_radius, cuboid_offset_y + half_sp, z_support_start],
         [cuboid_offset_x + hx + edge_radius, cuboid_offset_y + half_sp, z_cuboid_top]],
        // -X face: two posts spread along Y
        [[cuboid_offset_x - hx - edge_radius, cuboid_offset_y - half_sp, z_support_start],
         [cuboid_offset_x - hx - edge_radius, cuboid_offset_y - half_sp, z_cuboid_top]],
        [[cuboid_offset_x - hx - edge_radius, cuboid_offset_y + half_sp, z_support_start],
         [cuboid_offset_x - hx - edge_radius, cuboid_offset_y + half_sp, z_cuboid_top]]
    ] : [
        [[cuboid_offset_x, cuboid_offset_y + hy + edge_radius, z_support_start],
         [cuboid_offset_x, cuboid_offset_y + hy + edge_radius, z_cuboid_top]],
        [[cuboid_offset_x, cuboid_offset_y - hy - edge_radius, z_support_start],
         [cuboid_offset_x, cuboid_offset_y - hy - edge_radius, z_cuboid_top]],
        [[cuboid_offset_x + hx + edge_radius, cuboid_offset_y, z_support_start],
         [cuboid_offset_x + hx + edge_radius, cuboid_offset_y, z_cuboid_top]],
        [[cuboid_offset_x - hx - edge_radius, cuboid_offset_y, z_support_start],
         [cuboid_offset_x - hx - edge_radius, cuboid_offset_y, z_cuboid_top]]
    ];
    cuboid_bottom_connectors = [
        for (line = supports) [center_start, line[0]]
    ];
    union() {
        // Spine + base link sit on the rig axis (rotation-invariant)
        _local_draw_edge(center_start, center_end, edge_radius);
        _local_draw_edge([0, 0, z_bottom], center_start, edge_radius);

        // Posts + connectors yaw about the rig centre (offset_x, offset_y)
        translate([cuboid_offset_x, cuboid_offset_y, 0])
        rotate([0, 0, cuboid_rotation])
        translate([-cuboid_offset_x, -cuboid_offset_y, 0])
        union() {
            for (line = supports) {
                _local_draw_edge(line[0], line[1], edge_radius);
                translate(line[0]) sphere(r = vertex_radius);
            }
            for (conn = cuboid_bottom_connectors) {
                _local_draw_edge(conn[0], conn[1], edge_radius);
            }
        }
    }

    // Translucent reference box (rotated about the rig centre)
    translate([cuboid_offset_x, cuboid_offset_y, z_cuboid_bot + cuboid_height/2])
        rotate([0, 0, cuboid_rotation])
            %cube([cuboid_width, cuboid_depth, cuboid_height], center=true);
}
