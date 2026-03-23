enum AspectRatioType {
  ratio9x16,
  ratio1x1,
  ratio16x9,
}

extension AspectRatioTypeX on AspectRatioType {
  double get value => switch (this) {
        AspectRatioType.ratio9x16 => 9 / 16,
        AspectRatioType.ratio1x1 => 1.0,
        AspectRatioType.ratio16x9 => 16 / 9,
      };

  String get label => switch (this) {
        AspectRatioType.ratio9x16 => '9:16',
        AspectRatioType.ratio1x1 => '1:1',
        AspectRatioType.ratio16x9 => '16:9',
      };

  /// 출력 해상도 (width, height)
  (int, int) get outputSize => switch (this) {
        AspectRatioType.ratio9x16 => (1080, 1920),
        AspectRatioType.ratio1x1 => (1080, 1080),
        AspectRatioType.ratio16x9 => (1920, 1080),
      };
}
