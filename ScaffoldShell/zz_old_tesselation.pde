// --------------------------------------------------------------------------------
// PREVIOUS VERSION: Strip-wide texture version 1  (one image spanning the whole strip) -----------------------
// Mesh:
//  --> Same as before, one quad per edge-column (envelope of full column height), drawn as 2 triangles
// UV mapping (horizontal continuity):
// --> Use 1 image, give each column a horizontal slice of that image (based on the width of the column)
// --> creating a position 'u' on the image so i can line up the slices without any gaps.
// Math:
// - For column (e), average width wAvg[e] = 0.5 * (topLen[e] + bottomLen[e])
//  - SUM wAvg across all columns = sumAvg.
//  - Map u SUM [0, img.width] with uScale = img.width / sumAvg
//  - Column e consumes [u0, u1] = [uAcc, uAcc + wAvg[e]] * uScale, then uAcc += wAvg[e]
//   - Height/vertical side (v) uses full image height [0, img.height]
// Placement/bending is done:
// --> for each column, we place it using the same rotation+ move steps for the strips outlines.
// SO: Each quad is drawn in the column’s local frame, next advance to next column using the SAME translate+rotate math as panel placement doing:
// translate(currentBottomLen, 0); + rotate( atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x) )
//     where A_r = ((t - b)/2, h) is the current right slant
//           B_l = ((bNext - tNext)/2, h) is the next left slant
//
// --> UV continuity: u1(e) == u0(e+1)
// --> Geometric continuity: identical transforms as panels, so the image follows the strip bends
// -----------------------------------------------------------------------------
