enum AudioTrackType {
  original,  // 原音轨
  silent,    // 静音
  custom,    // 自定义音频文件
}

class AudioTrackData {
  final AudioTrackType type;
  final String label;
  final String description;
  final String? filePath; // 自定义音频文件路径

  const AudioTrackData({
    required this.type,
    required this.label,
    required this.description,
    this.filePath,
  });
}

class AudioTracks {
  static const List<AudioTrackData> predefined = [
    AudioTrackData(
      type: AudioTrackType.original,
      label: '原音轨',
      description: '保持视频原有的音频',
    ),
    AudioTrackData(
      type: AudioTrackType.silent,
      label: '静音',
      description: '移除所有音频',
    ),
    AudioTrackData(
      type: AudioTrackType.custom,
      label: '自定义音频',
      description: '添加外部音频文件',
    ),
  ];

  static AudioTrackData getByType(AudioTrackType type) {
    return predefined.firstWhere((data) => data.type == type);
  }
}