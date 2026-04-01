enum ExportQuality { low, medium, high }

extension ExportQualityX on ExportQuality {
  String get label => switch (this) {
        ExportQuality.low => '낮음',
        ExportQuality.medium => '중간',
        ExportQuality.high => '높음',
      };

  String get crf => switch (this) {
        ExportQuality.low => '28',
        ExportQuality.medium => '23',
        ExportQuality.high => '18',
      };

  String get preset => switch (this) {
        ExportQuality.low => 'veryfast',
        ExportQuality.medium => 'fast',
        ExportQuality.high => 'medium',
      };
}
