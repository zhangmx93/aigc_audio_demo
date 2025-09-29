import 'dart:io';

import 'package:aigc_audio_demo/data/audio_tracks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'components/jianying_timeline.dart';
import 'components/export_format_selector.dart';
import 'components/audio_track_selector.dart';
import 'controllers/ffmpeg_cropper_controller.dart';
import 'services/gallery_service.dart';
import 'services/permission_manager.dart';

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
    
    // 在应用启动时预先请求权限
    _requestPermissionsOnStartup();
  }

  /// 启动时请求权限
  void _requestPermissionsOnStartup() async {
    try {
      await PermissionManager.requestAllPermissions();
    } catch (e) {
      // 静默处理权限请求错误，用户可以在保存时再次请求
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('建议授予相册权限以保存编辑后的视频'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _controller.isRunning ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: const Text('选择视频'),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _controller.isRunning || _controller.inputPath == null
                        ? null
                        : _controller.cropCenterSquare,
                    icon: const Icon(Icons.crop_square),
                    label: const Text('执行裁剪'),
                  ),
                  // Export format selector
                  ExportFormatSelector(
                    selectedFormat: _controller.exportFormat,
                    onChanged: (format) {
                      _controller.setExportFormat(format);
                    },
                    enabled: !_controller.isRunning,
                  ),
                  // Audio track selector
                  // AudioTrackSelector(
                  //   selectedTrackType: _controller.audioTrackType,
                  //   customAudioPath: _controller.customAudioPath,
                  //   onTrackTypeChanged: (type) {
                  //     _controller.setAudioTrackType(type);
                  //   },
                  //   onCustomAudioChanged: (path) {
                  //     _controller.setCustomAudioPath(path);
                  //   },
                  //   enabled: !_controller.isRunning,
                  // ),
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
                  ),
                ),

              const SizedBox(height: 12),

              // Jianying-style timeline
              if (_controller.hasVideo)
                SizedBox(
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
                    onAudioFileSelected: (path) async {
                      if (path == null) {
                        _controller.setCustomAudioPath(null);
                        _controller.setAudioTrackType(AudioTrackType.original);
                      } else if (path.startsWith('assets/')) {
                        // Use asset audio directly
                        _controller.setCustomAudioPath(path);
                        _controller.setAudioTrackType(AudioTrackType.custom);
                      } else if (path == 'placeholder_path') {
                        // Show file picker for custom audio
                        final result = await FilePicker.platform.pickFiles(type: FileType.audio);
                        if (result != null && result.files.single.path != null) {
                          final audioPath = result.files.single.path!;
                          _controller.setCustomAudioPath(audioPath);
                          _controller.setAudioTrackType(AudioTrackType.custom);
                        }
                      } else {
                        // Direct file path provided
                        _controller.setCustomAudioPath(path);
                        _controller.setAudioTrackType(AudioTrackType.custom);
                      }
                    },
                    customAudioPath: _controller.customAudioPath,
                  ),
                ),

              if (_controller.isRunning) const LinearProgressIndicator(),
              if (_controller.log != null) ...[
                const SizedBox(height: 8),
                Text(_controller.log!),
              ],
              const SizedBox(height: 8),
              Text('输出: ${_controller.outputPath ?? '-'}'),
              const SizedBox(height: 8),
              if (_controller.outputPath != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final out = _controller.outputPath!;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final exists = await File(out).exists();
                        if (!mounted) return;
                        if (exists) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('文件位置: $out')),
                          );
                        }
                      },
                      icon: const Icon(Icons.folder),
                      label: const Text('查看文件'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final out = _controller.outputPath!;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        
                        // 显示加载指示器
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text('正在保存到相册...'),
                              ],
                            ),
                          ),
                        );
                        
                        final success = await GalleryService.saveVideoToGallery(out);
                        
                        if (!mounted) return;
                        navigator.pop(); // 关闭加载对话框
                        
                        if (success) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('✅ 视频已成功保存到相册'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('❌ 保存到相册失败，请检查权限设置'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_alt),
                      label: const Text('保存到相册'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
