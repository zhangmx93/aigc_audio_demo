import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../data/export_formats.dart';
import '../data/audio_tracks.dart';

class FfmpegCropperController extends ChangeNotifier {
  String? _inputPath;
  String? _outputPath;
  String? _log;
  bool _isRunning = false;
  bool _isDisposed = false; // 添加dispose标志

  VideoPlayerController? _player;
  AudioPlayer? _audioPlayer;
  Duration _duration = Duration.zero;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  bool _isSeeking = false;

  final List<String> _thumbnails = <String>[];
  bool _isGeneratingThumbs = false;
  bool _isMuted = false;
  ExportFormat _exportFormat = ExportFormat.mov;
  AudioTrackType _audioTrackType = AudioTrackType.original;
  String? _customAudioPath;
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
  ExportFormat get exportFormat => _exportFormat;
  AudioTrackType get audioTrackType => _audioTrackType;
  String? get customAudioPath => _customAudioPath;
  
  // 获取当前是否正在播放
  bool get isPlaying => _player?.value.isPlaying ?? false;

  void _updateState() {
    if (_isDisposed) return; // 如果已经disposed，不再调用notifyListeners
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

  void setExportFormat(ExportFormat format) {
    _exportFormat = format;
    _updateState();
  }

  void setAudioTrackType(AudioTrackType type) {
    _audioTrackType = type;
    // 如果不是自定义音频，清除自定义音频路径
    if (type != AudioTrackType.custom) {
      _customAudioPath = null;
    }
    // 如果是静音，同时设置播放器静音
    if (type == AudioTrackType.silent) {
      _isMuted = true;
      _applyMuteToPlayer();
    } else if (type == AudioTrackType.original) {
      _isMuted = false;
      _applyMuteToPlayer();
    }
    _updateState();
  }

  void setCustomAudioPath(String? path) async {
    if (_isDisposed) return; // 检查是否已dispose
    
    _customAudioPath = path;
    if (path != null) {
      _audioTrackType = AudioTrackType.custom;
      // 自定义音频时，视频播放器静音，但视频依然播放
      _isMuted = true;
      _applyMuteToPlayer();
      
      // 初始化音频播放器
      await _initAudioPlayer(path);
    } else {
      // 清理音频播放器并恢复原音轨
      await _disposeAudioPlayer();
      _audioTrackType = AudioTrackType.original;
      _isMuted = false;
      _applyMuteToPlayer();
    }
    _updateState();
  }

  /// 初始化音频播放器
  Future<void> _initAudioPlayer(String audioPath) async {
    if (_isDisposed) return; // 检查是否已dispose
    
    try {
      await _disposeAudioPlayer(); // 清理旧的播放器
      
      if (_isDisposed) return; // 在清理后再次检查
      
      _audioPlayer = AudioPlayer();
      
      if (audioPath.startsWith('assets/')) {
        // Asset音频
        await _audioPlayer!.setAsset(audioPath);
      } else {
        // 文件路径音频
        await _audioPlayer!.setFilePath(audioPath);
      }
      
      if (_isDisposed) return; // 在设置后检查
      
      // 设置循环播放模式以匹配视频长度
      await _audioPlayer!.setLoopMode(LoopMode.one);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing audio player: $e');
      }
      await _disposeAudioPlayer();
    }
  }

  /// 清理音频播放器
  Future<void> _disposeAudioPlayer() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
      } catch (e) {
        if (kDebugMode) {
          print('Error disposing audio player: $e');
        }
      } finally {
        _audioPlayer = null;
      }
    }
  }

  /// Copy asset file to temporary directory for FFmpeg processing
  Future<String?> _copyAssetToTemp(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final buffer = data.buffer;
      final dir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final tempFile = File('${dir.path}/$fileName');
      await tempFile.writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      return tempFile.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error copying asset: $e');
      }
      return null;
    }
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
      _seekToTrimStart(); // 只seek，不播放
      return;
    }
    if (position > _trimEnd) {
      // 跳回开头并继续播放（循环播放效果）
      _seekToTrimStart().then((_) {
        if (!_isDisposed && p.value.isPlaying) {
          p.play();
          if (_audioPlayer != null && _audioTrackType == AudioTrackType.custom) {
            _audioPlayer!.play();
          }
        }
      });
    }
  }

  Future<void> _seekToTrimStart({bool playAfterSeek = false}) async {
    if (_isDisposed) return; // 检查是否已dispose
    
    final p = _player;
    if (p == null) return;
    _isSeeking = true;
    try {
      final seekPosition = Duration(milliseconds: (_trimStart * 1000).round());
      await p.seekTo(seekPosition);
      
      // 如果有自定义音频，同步音频播放位置（但不播放）
      if (!_isDisposed && _audioPlayer != null && _audioTrackType == AudioTrackType.custom) {
        await _audioPlayer!.seek(seekPosition);
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
      final formatData = ExportFormats.getByFormat(_exportFormat);
      final outPath =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.${formatData.extension}';

      final filter = 'crop=$minSide:$minSide:$x:$y';
      final ss = startSec.toStringAsFixed(3);
      final t = durSec.toStringAsFixed(3);
      
      // Build FFmpeg command with audio track support
      String audioParam;
      List<String> inputParams = ["-i '$input'"];
      String filterComplex = "";
      
      switch (_audioTrackType) {
        case AudioTrackType.original:
          audioParam = '-c:a copy';
          break;
        case AudioTrackType.silent:
          audioParam = '-an'; // Remove audio track
          break;
        case AudioTrackType.custom:
          if (_customAudioPath != null) {
            String? actualAudioPath;
            
            // Check if it's an asset path or a file path
            if (_customAudioPath!.startsWith('assets/')) {
              // Copy asset to temporary directory
              actualAudioPath = await _copyAssetToTemp(_customAudioPath!);
            } else if (File(_customAudioPath!).existsSync()) {
              // Use existing file path
              actualAudioPath = _customAudioPath!;
            }
            
            if (actualAudioPath != null) {
              // Add custom audio as second input
              inputParams.add("-i '$actualAudioPath'");
              // Mix video with custom audio, keeping video length
              filterComplex = "-filter_complex \"[0:v]$filter[v];[1:a]atrim=duration=$t[a]\" -map \"[v]\" -map \"[a]\" -c:v libx264 -preset veryfast -crf 23 -c:a aac";
              audioParam = "";
            } else {
              // Fallback to silent if custom audio not found
              audioParam = '-an';
            }
          } else {
            // Fallback to silent if custom audio not found
            audioParam = '-an';
          }
          break;
      }
      
      String cmd;
      if (filterComplex.isNotEmpty) {
        // Custom audio command
        cmd = "-y ${inputParams.join(' ')} -ss $ss -t $t $filterComplex '$outPath'";
      } else {
        // Standard command
        cmd = "-y -i '$input' -ss $ss -t $t -vf $filter -c:v libx264 -preset veryfast -crf 23 $audioParam '$outPath'";
      }

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
    if (_isDisposed) return; // 检查是否已dispose
    
    final p = _player;
    if (p == null) return;
    
    if (p.value.isPlaying) {
      // 暂停播放
      await p.pause();
      // 如果有自定义音频，也暂停音频播放
      if (!_isDisposed && _audioPlayer != null && _audioTrackType == AudioTrackType.custom) {
        await _audioPlayer!.pause();
      }
    } else {
      // 开始播放
      // 确保视频和音频都从trim start位置开始
      await _seekToTrimStart();
      if (_isDisposed) return;
      
      // 同时开始播放视频和音频
      await p.play();
      if (!_isDisposed && _audioPlayer != null && _audioTrackType == AudioTrackType.custom) {
        await _audioPlayer!.play();
      }
    }
    _updateState();
  }

  Future<void> seekTo(Duration position) async {
    if (_isDisposed) return; // 检查是否已dispose
    
    final p = _player;
    if (p == null) return;
    _isSeeking = true;
    try {
      await p.seekTo(position);
      // 如果有自定义音频，同步音频播放位置
      if (!_isDisposed && _audioPlayer != null && _audioTrackType == AudioTrackType.custom) {
        await _audioPlayer!.seek(position);
      }
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
    _isDisposed = true; // 设置dispose标志
    _player?.removeListener(_onTick);
    _player?.dispose();
    _disposeAudioPlayer();
    _clearThumbnails();
    super.dispose();
  }
}