enum ExportFormat {
  mov,
  mp4,
  avi,
}

class ExportFormatData {
  final ExportFormat format;
  final String label;
  final String extension;
  final String description;

  const ExportFormatData({
    required this.format,
    required this.label,
    required this.extension,
    required this.description,
  });
}

class ExportFormats {
  static const List<ExportFormatData> all = [
    ExportFormatData(
      format: ExportFormat.mov,
      label: 'MOV',
      extension: 'mov',
      description: 'Apple QuickTime Movie',
    ),
    ExportFormatData(
      format: ExportFormat.mp4,
      label: 'MP4',
      extension: 'mp4',
      description: 'MPEG-4 Video',
    ),
    ExportFormatData(
      format: ExportFormat.avi,
      label: 'AVI',
      extension: 'avi',
      description: 'Audio Video Interleave',
    ),
  ];

  static ExportFormatData getByFormat(ExportFormat format) {
    return all.firstWhere((data) => data.format == format);
  }

  static ExportFormatData getByExtension(String extension) {
    return all.firstWhere((data) => data.extension == extension);
  }
}