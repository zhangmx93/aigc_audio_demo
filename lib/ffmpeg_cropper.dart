import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:video_player/video_player.dart';

class FfmpegCropperScreen extends StatefulWidget {
  const FfmpegCropperScreen({super.key});

  @override
  State<FfmpegCropperScreen> createState() => _FfmpegCropperScreenState();
}

class _FfmpegCropperScreenState extends State<FfmpegCropperScreen> {
  String? _inputPath;
  String? _outputPath;
  String? _log;
  bool _isRunning = false;

  VideoPlayerController? _player;
  Duration _duration = Duration.zero;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  bool _isSeeking = false;

  // Thumbnails state
  final List<String> _thumbnails = <String>[];
  bool _isGeneratingThumbs = false;
  static const int _thumbCount = 12;

  // Drag handle config
  static const double _handleWidth = 10.0;
  static const double _minSelectionSeconds = 0.1;

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final picked = result.files.single.path!;
      await _initPlayer(picked);
      setState(() {
        _inputPath = picked;
        _outputPath = null;
        _log = null;
      });
    }
  }

  Future<void> _initPlayer(String path) async {
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
      await controller.setLooping(false); // we implement our own loop in range
      controller.addListener(_onTick);
      setState(() {
        _player = controller;
      });
      _seekToTrimStart();
      controller.play();
      // Generate timeline thumbnails
      _generateThumbnails(path);
    } catch (e) {
      setState(() => _log = '播放器初始化失败: $e');
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

  Future<void> _generateThumbnails(String inputPath) async {
    if (!mounted) return;
    setState(() {
      _isGeneratingThumbs = true;
      _thumbnails.clear();
    });
    try {
      final dir = await getTemporaryDirectory();
      final thumbsDir = Directory('${dir.path}/thumbs_${DateTime.now().millisecondsSinceEpoch}');
      if (!thumbsDir.existsSync()) thumbsDir.createSync(recursive: true);

      // Evenly spaced timestamps across duration
      final totalSec = _duration.inMilliseconds / 1000.0;
      final safeTotal = totalSec <= 0 ? 1.0 : totalSec;
      for (int i = 0; i < _thumbCount; i++) {
        final ts = ((i + 0.5) * (safeTotal / _thumbCount));
        final out = '${thumbsDir.path}/t_${i.toString().padLeft(2, '0')}.jpg';
        final cmd = "-y -ss ${ts.toStringAsFixed(3)} -i '${inputPath}' -frames:v 1 -vf scale=320:-1 '${out}'";
        final session = await FFmpegKit.execute(cmd);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(out).existsSync()) {
          _thumbnails.add(out);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      setState(() => _log = '缩略图生成失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingThumbs = false;
        });
      }
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
      setState(() => _log = 'Probe error: $e');
      return null;
    }
  }

  Future<void> _cropCenterSquare() async {
    final input = _inputPath;
    if (input == null) return;

    // Normalize trim
    final total = _duration.inMilliseconds / 1000.0;
    final start = _trimStart.clamp(0.0, total);
    final end = _trimEnd.clamp(0.0, total);
    final startSec = start;
    final durSec = (end > start) ? (end - start) : (total - start);

    setState(() {
      _isRunning = true;
      _log = 'Running...';
      _outputPath = null;
    });

    try {
      final size = await _probeSize(input);
      if (size == null) {
        setState(() {
          _isRunning = false;
          _log = '无法读取视频尺寸';
        });
        return;
      }

      final minSide = size.width < size.height ? size.width : size.height;
      final x = ((size.width - minSide) / 2).floor();
      final y = ((size.height - minSide) / 2).floor();

      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final filter = 'crop=${minSide}:${minSide}:${x}:${y}';
      final ss = startSec.toStringAsFixed(3);
      final t = durSec.toStringAsFixed(3);
      final cmd =
          "-y -i '${input}' -ss ${ss} -t ${t} -vf ${filter} -c:v libx264 -preset veryfast -crf 23 -c:a copy '${outPath}'";

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      final success = ReturnCode.isSuccess(rc);

      setState(() {
        _isRunning = false;
        if (success && File(outPath).existsSync()) {
          _outputPath = outPath;
          _log = '裁剪完成';
        } else {
          _log = '裁剪失败: ${rc?.getValue()}';
        }
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _log = '执行错误: $e';
      });
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    _clearThumbnails();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _player != null && _player!.value.isInitialized;

    return Scaffold(
      appBar: AppBar(title: const Text('FFmpeg 方形裁剪')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRunning ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: const Text('选择视频'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isRunning || _inputPath == null
                        ? null
                        : _cropCenterSquare,
                    icon: const Icon(Icons.crop_square),
                    label: const Text('执行裁剪'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),

              // Preview
              if (hasVideo)
                AspectRatio(
                  aspectRatio: _player!.value.aspectRatio == 0
                      ? 16 / 9
                      : _player!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(_player!),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _isRunning
                                ? null
                                : () async {
                                    if (_player!.value.isPlaying) {
                                      await _player!.pause();
                                    } else {
                                      await _seekToTrimStart();
                                      await _player!.play();
                                    }
                                    setState(() {});
                                  },
                            icon: Icon(
                              _player!.value.isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                            ),
                            iconSize: 42,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Thumbnail timeline with draggable handles
              if (hasVideo)
                SizedBox(
                  height: 100,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final totalSec = _duration.inMilliseconds / 1000.0;
                      final count = _thumbnails.isEmpty ? _thumbCount : _thumbnails.length;
                      final itemWidth = width / count;

                      double secToDx(double sec) => (sec / totalSec) * width;
                      double dxToSec(double dx) => (dx / width) * totalSec;

                      final leftDx = secToDx(_trimStart);
                      final rightDx = secToDx(_trimEnd);

                      return Stack(
                        children: [
                          Row(
                            children: [
                              for (int i = 0; i < count; i++)
                                SizedBox(
                                  width: itemWidth,
                                  height: 100,
                                  child: _thumbnails.length > i
                                      ? Image.file(
                                          File(_thumbnails[i]),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.black12,
                                          child: _isGeneratingThumbs
                                              ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                              : const SizedBox.shrink(),
                                        ),
                                ),
                            ],
                          ),

                          // Shaded outside area
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ShadePainter(
                                left: leftDx,
                                right: rightDx,
                                handleWidth: _handleWidth,
                              ),
                            ),
                          ),

                          // Left handle
                          Positioned(
                            left: (leftDx - _handleWidth / 2).clamp(0.0, width - _handleWidth),
                            top: 0,
                            bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanUpdate: (details) async {
                                final dx = (leftDx + details.delta.dx).clamp(0.0, rightDx - _handleWidth);
                                final newStart = dxToSec(dx);
                                final minEnd = newStart + _minSelectionSeconds;
                                setState(() {
                                  _trimStart = newStart.clamp(0.0, totalSec);
                                  _trimEnd = _trimEnd < minEnd ? minEnd.clamp(0.0, totalSec) : _trimEnd;
                                });
                                await _seekToTrimStart(playAfterSeek: _player!.value.isPlaying);
                              },
                              child: _HandleWidget(isLeft: true, height: 100, width: _handleWidth),
                            ),
                          ),

                          // Right handle
                          Positioned(
                            left: (rightDx - _handleWidth / 2).clamp(0.0, width - _handleWidth),
                            top: 0,
                            bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanUpdate: (details) async {
                                final dx = (rightDx + details.delta.dx).clamp(leftDx + _handleWidth, width);
                                final newEnd = dxToSec(dx);
                                final minEnd = _trimStart + _minSelectionSeconds;
                                setState(() {
                                  _trimEnd = newEnd.clamp(minEnd, totalSec);
                                });
                                await _seekToTrimStart(playAfterSeek: _player!.value.isPlaying);
                              },
                              child: _HandleWidget(isLeft: false, height: 100, width: _handleWidth),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              if (_isRunning) const LinearProgressIndicator(),
              if (_log != null) ...[const SizedBox(height: 8), Text(_log!)],
              const SizedBox(height: 8),
              Text('输出: ${_outputPath ?? '-'}'),
              const SizedBox(height: 8),
              if (_outputPath != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    final out = _outputPath!;
                    if (await File(out).exists()) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已保存到: $out')));
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('完成'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShadePainter extends CustomPainter {
  final double left;
  final double right;
  final double handleWidth;
  _ShadePainter({required this.left, required this.right, required this.handleWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paintShade = Paint()..color = const Color(0x88000000);
    // Left shaded area
    canvas.drawRect(Rect.fromLTWH(0, 0, left, size.height), paintShade);
    // Right shaded area
    canvas.drawRect(Rect.fromLTWH(right, 0, size.width - right, size.height), paintShade);
    // Selection border
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(left, 0, right - left, size.height), border);
  }

  @override
  bool shouldRepaint(covariant _ShadePainter oldDelegate) {
    return oldDelegate.left != left || oldDelegate.right != right || oldDelegate.handleWidth != handleWidth;
  }
}

class _HandleWidget extends StatelessWidget {
  final bool isLeft;
  final double height;
  final double width;
  const _HandleWidget({required this.isLeft, required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: isLeft ? const BorderSide(color: Colors.blueAccent, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.blueAccent, width: 3) : BorderSide.none,
        ),
      ),
      child: Center(
        child: Container(
          width: 3,
          height: height * 0.6,
          color: Colors.blueAccent,
        ),
      ),
    );
  }
}
