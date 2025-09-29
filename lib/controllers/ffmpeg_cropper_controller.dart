import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:video_player/video_player.dart';

class FfmpegCropperController extends ChangeNotifier {
  String? _inputPath;
  String? _outputPath;
  String? _log;
  bool _isRunning = false;

  VideoPlayerController? _player;
  Duration _duration = Duration.zero;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  bool _isSeeking = false;

  final List<String> _thumbnails = <String>[];
  bool _isGeneratingThumbs = false;
  bool _isMuted = false;
  String _exportFormat = 'mov';
  // Thumbnail generation based on frame rate
  static const double _thumbnailFrameRate = 1.0; // 1 thumbnail per second
  static const int _maxThumbnails = 60; // Maximum thumbnails to prevent excessive generation

  // View size control
  double _viewWidth = 400.0;
  static const double _minWidth = 200.0;
  static const double _maxWidth = 800.0;

  String? get inputPath => _inputPath;
  String? get outputPath => _outputPath;
  String? get log => _log;
  bool get isRunning => _isRunning;
  VideoPlayerController? get player => _player;
  Duration get duration => _duration;
  double get trimStart => _trimStart;
  double get trimEnd => _trimEnd;
  List<String> get thumbnails => _thumbnails;
  bool get isGeneratingThumbs => _isGeneratingThumbs;
  bool get hasVideo => _player != null && _player!.value.isInitialized;
  double get viewWidth => _viewWidth;
  double get minWidth => _minWidth;
  double get maxWidth => _maxWidth;
  Duration get currentPosition => _player?.value.position ?? Duration.zero;
  bool get isMuted => _isMuted;
  String get exportFormat => _exportFormat;

  void _updateState() {
    notifyListeners();
  }

  void setInputPath(String? path) {
    _inputPath = path;
    _outputPath = null;
    _log = null;
    _updateState();
  }

  void setLog(String? log) {
    _log = log;
    _updateState();
  }

  void setRunning(bool running) {
    _isRunning = running;
    _updateState();
  }

  void setOutputPath(String? path) {
    _outputPath = path;
    _updateState();
  }

  void setTrimStart(double start) {
    _trimStart = start;
    _updateState();
  }

  void setTrimEnd(double end) {
    _trimEnd = end;
    _updateState();
  }

  void setTrimRange(double start, double end) {
    _trimStart = start;
    _trimEnd = end;
    _updateState();
  }

  void setViewWidth(double width) {
    _viewWidth = width.clamp(_minWidth, _maxWidth);
    _updateState();
  }

  void increaseViewSize() {
    setViewWidth(_viewWidth + 50);
  }

  void decreaseViewSize() {
    setViewWidth(_viewWidth - 50);
  }

  void resetViewSize() {
    setViewWidth(400.0);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _applyMuteToPlayer();
    _updateState();
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    _applyMuteToPlayer();
    _updateState();
  }

  void _applyMuteToPlayer() {
    final p = _player;
    if (p != null && p.value.isInitialized) {
      p.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  void setExportFormat(String format) {
    _exportFormat = format;
    _updateState();
  }

  Future<void> initPlayer(String path) async {
    try {
      final old = _player;
      if (old != null) {
        old.removeListener(_onTick);
        await old.pause();
        await old.dispose();
      }
      await _clearThumbnails();
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      _duration = controller.value.duration;
      _trimStart = 0.0;
      _trimEnd = _duration.inMilliseconds / 1000.0;
      await controller.setLooping(false);
      controller.addListener(_onTick);
      _player = controller;
      _applyMuteToPlayer(); // Apply current mute state to new player
      _updateState();
      _seekToTrimStart();
      controller.play();
      _generateThumbnails(path);
    } catch (e) {
      setLog('播放器初始化失败: $e');
    }
  }

  void _onTick() {
    final p = _player;
    if (p == null || !p.value.isInitialized || _isSeeking) return;
    final position = p.value.position.inMilliseconds / 1000.0;
    if (position < _trimStart - 0.02) {
      _seekToTrimStart();
      return;
    }
    if (position > _trimEnd) {
      _seekToTrimStart(playAfterSeek: true);
    }
  }

  Future<void> _seekToTrimStart({bool playAfterSeek = true}) async {
    final p = _player;
    if (p == null) return;
    _isSeeking = true;
    try {
      await p.seekTo(Duration(milliseconds: (_trimStart * 1000).round()));
      if (playAfterSeek) {
        await p.play();
      }
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> seekToTrimStart({bool playAfterSeek = true}) async {
    await _seekToTrimStart(playAfterSeek: playAfterSeek);
  }

  Future<void> _generateThumbnails(String inputPath) async {
    _isGeneratingThumbs = true;
    _thumbnails.clear();
    _updateState();

    try {
      final dir = await getTemporaryDirectory();
      final thumbsDir = Directory('${dir.path}/thumbs_${DateTime.now().millisecondsSinceEpoch}');
      if (!thumbsDir.existsSync()) thumbsDir.createSync(recursive: true);

      final totalSec = _duration.inMilliseconds / 1000.0;
      if (totalSec <= 0) return;
      
      // Calculate number of thumbnails based on frame rate
      final thumbnailCount = (totalSec * _thumbnailFrameRate).round().clamp(1, _maxThumbnails);
      final interval = totalSec / thumbnailCount;
      
      for (int i = 0; i < thumbnailCount; i++) {
        final ts = i * interval + (interval / 2); // Center of each interval
        final out = '${thumbsDir.path}/t_${i.toString().padLeft(3, '0')}.jpg';
        final cmd = "-y -ss ${ts.toStringAsFixed(3)} -i '$inputPath' -frames:v 1 -vf scale=320:-1 '$out'";
        final session = await FFmpegKit.execute(cmd);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(out).existsSync()) {
          _thumbnails.add(out);
          _updateState();
        }
      }
    } catch (e) {
      setLog('缩略图生成失败: $e');
    } finally {
      _isGeneratingThumbs = false;
      _updateState();
    }
  }

  Future<void> _clearThumbnails() async {
    try {
      for (final path in _thumbnails) {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (_) {}
    _thumbnails.clear();
  }

  Future<({int width, int height})?> _probeSize(String path) async {
    try {
      final MediaInformationSession session =
          await FFprobeKit.getMediaInformation(path);
      final MediaInformation? info = session.getMediaInformation();
      if (info == null) return null;
      final streams = info.getStreams();
      if (streams.isEmpty) return null;
      final videoStream = streams.firstWhere(
        (s) =>
            (s.getAllProperties()?['codec_type']?.toString() ?? '') == 'video',
        orElse: () => streams.first,
      );
      final props = videoStream.getAllProperties() ?? {};
      final width = int.tryParse(props['width']?.toString() ?? '');
      final height = int.tryParse(props['height']?.toString() ?? '');
      if (width == null || height == null) return null;
      return (width: width, height: height);
    } catch (e) {
      setLog('Probe error: $e');
      return null;
    }
  }

  Future<void> cropCenterSquare() async {
    final input = _inputPath;
    if (input == null) return;

    final total = _duration.inMilliseconds / 1000.0;
    final start = _trimStart.clamp(0.0, total);
    final end = _trimEnd.clamp(0.0, total);
    final startSec = start;
    final durSec = (end > start) ? (end - start) : (total - start);

    setRunning(true);
    setLog('Running...');
    setOutputPath(null);

    try {
      final size = await _probeSize(input);
      if (size == null) {
        setRunning(false);
        setLog('无法读取视频尺寸');
        return;
      }

      final minSide = size.width < size.height ? size.width : size.height;
      final x = ((size.width - minSide) / 2).floor();
      final y = ((size.height - minSide) / 2).floor();

      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.$_exportFormat';

      final filter = 'crop=$minSide:$minSide:$x:$y';
      final ss = startSec.toStringAsFixed(3);
      final t = durSec.toStringAsFixed(3);
      
      // Build FFmpeg command with mute support
      String audioParam;
      if (_isMuted) {
        audioParam = '-an'; // Remove audio track
      } else {
        audioParam = '-c:a copy'; // Copy audio track
      }
      
      final cmd =
          "-y -i '$input' -ss $ss -t $t -vf $filter -c:v libx264 -preset veryfast -crf 23 $audioParam '$outPath'";

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      final success = ReturnCode.isSuccess(rc);

      setRunning(false);
      if (success && File(outPath).existsSync()) {
        setOutputPath(outPath);
        setLog('裁剪完成');
      } else {
        setLog('裁剪失败: ${rc?.getValue()}');
      }
    } catch (e) {
      setRunning(false);
      setLog('执行错误: $e');
    }
  }

  Future<void> playPause() async {
    final p = _player;
    if (p == null) return;
    
    if (p.value.isPlaying) {
      await p.pause();
    } else {
      await _seekToTrimStart();
      await p.play();
    }
    _updateState();
  }

  Future<void> seekTo(Duration position) async {
    final p = _player;
    if (p == null) return;
    _isSeeking = true;
    try {
      await p.seekTo(position);
      _updateState();
    } finally {
      _isSeeking = false;
    }
  }

  void splitAtCurrentPosition() {
    // TODO: Implement video splitting functionality
    if (kDebugMode) {
      print('Split at position: ${currentPosition.inSeconds}s');
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    _clearThumbnails();
    super.dispose();
  }
}