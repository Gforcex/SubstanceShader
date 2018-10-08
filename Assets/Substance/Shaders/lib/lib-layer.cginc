
float bayerMatrix8(uvec2 coords) {
  return (float(bayer(coords.x, coords.y)) + 0.5) / 64.0;
}