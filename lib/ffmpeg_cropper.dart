import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'components/jianying_timeline.dart';
import 'controllers/ffmpeg_cropper_controller.dart';

class FfmpegCropperScreen extends StatefulWidget {
  const FfmpegCropperScreen({super.key});

  @override
  State<FfmpegCropperScreen> createState() => _FfmpegCropperScreenState();
}

class _FfmpegCropperScreenState extends State<FfmpegCropperScreen> {
  late final FfmpegCropperController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FfmpegCropperController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }


  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final picked = result.files.single.path!;
      _controller.setInputPath(picked);
      await _controller.initPlayer(picked);
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: _controller.isRunning ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: const Text('选择视频'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _controller.isRunning || _controller.inputPath == null
                        ? null
                        : _controller.cropCenterSquare,
                    icon: const Icon(Icons.crop_square),
                    label: const Text('执行裁剪'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_controller.hasVideo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 68),
                  child: SizedBox(
                    width: _controller.viewWidth,
                  child: AspectRatio(
                    aspectRatio: _controller.player!.value.aspectRatio == 0
                        ? 16 / 9
                        : _controller.player!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller.player!),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _controller.isRunning
                                  ? null
                                  : _controller.playPause,
                              icon: Icon(
                                _controller.player!.value.isPlaying
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
                )),

              const SizedBox(height: 12),

              // Jianying-style timeline
              if (_controller.hasVideo)
                SizedBox(
                  height: 150,
                  child: JianyingTimeline(
                    thumbnails: _controller.thumbnails,
                    isGeneratingThumbs: _controller.isGeneratingThumbs,
                    duration: _controller.duration,
                    trimStart: _controller.trimStart,
                    trimEnd: _controller.trimEnd,
                    currentPosition: _controller.currentPosition,
                    isPlaying: _controller.player!.value.isPlaying,
                    isMuted: _controller.isMuted,
                    onTrimStartChanged: (newStart) {
                      _controller.setTrimStart(newStart);
                    },
                    onTrimEndChanged: (newEnd) {
                      _controller.setTrimEnd(newEnd);
                    },
                    onSeek: (position) async {
                      await _controller.seekTo(position);
                    },
                    onSplit: () {
                      _controller.splitAtCurrentPosition();
                    },
                    onMuteToggle: () {
                      _controller.toggleMute();
                    },
                  ),
                ),

              if (_controller.isRunning) const LinearProgressIndicator(),
              if (_controller.log != null) ...[const SizedBox(height: 8), Text(_controller.log!)],
              const SizedBox(height: 8),
              Text('输出: ${_controller.outputPath ?? '-'}'),
              const SizedBox(height: 8),
              if (_controller.outputPath != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    final out = _controller.outputPath!;
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final exists = await File(out).exists();
                    if (!mounted) return;
                    if (exists) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('已保存到: $out')),
                      );
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

