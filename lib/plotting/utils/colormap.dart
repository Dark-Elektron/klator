import 'dart:ui';

Color jetColormap(double t) {
  t = t.clamp(0.0, 1.0);

  if (t < 0.125) {
    return Color.lerp(
      const Color(0xFF000080),
      const Color(0xFF0000FF),
      t / 0.125,
    )!;
  } else if (t < 0.375) {
    return Color.lerp(
      const Color(0xFF0000FF),
      const Color(0xFF00FFFF),
      (t - 0.125) / 0.25,
    )!;
  } else if (t < 0.625) {
    return Color.lerp(
      const Color(0xFF00FFFF),
      const Color(0xFFFFFF00),
      (t - 0.375) / 0.25,
    )!;
  } else if (t < 0.875) {
    return Color.lerp(
      const Color(0xFFFFFF00),
      const Color(0xFFFF0000),
      (t - 0.625) / 0.25,
    )!;
  } else {
    return Color.lerp(
      const Color(0xFFFF0000),
      const Color(0xFF800000),
      (t - 0.875) / 0.125,
    )!;
  }
}

Color surfaceGradientColor(double t) {
  final colors = [
    const Color(0xFF1E88E5),
    const Color(0xFF00ACC1),
    const Color(0xFF00897B),
    const Color(0xFF43A047),
    const Color(0xFFFDD835),
  ];
  final scaledT = t * (colors.length - 1);
  final index = scaledT.floor().clamp(0, colors.length - 2);
  return Color.lerp(colors[index], colors[index + 1], scaledT - index)!;
}