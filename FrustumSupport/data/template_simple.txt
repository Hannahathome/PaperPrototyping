module frustum(
    frustum_nside, frustum_bottom_radius, frustum_top_radius, frustum_height, edge_radius
){
    vertex_radius = edge_radius;
    $fn = 16;
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
    }
}