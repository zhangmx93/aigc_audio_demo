import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_editor/video_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:math';

class AdvancedVideoEditor extends StatefulWidget {
  const AdvancedVideoEditor({super.key});

  @override
  State<AdvancedVideoEditor> createState() => _AdvancedVideoEditorState();
}

class _AdvancedVideoEditorState extends State<AdvancedVideoEditor> {
  VideoEditorController? _controller;
  bool _isLoading = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  
  // Editing properties
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  int _rotationAngle = 0;
  bool _showFilters = false;

  // Background music
  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _bgmPath;
  double _bgmVolume = 0.7;
  bool _bgmLoop = true;

  // Multi-clip support
  final List<File> _clips = [];
  int _currentClipIndex = -1;

  @override
  void dispose() {
    _controller?.dispose();
    _bgmPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final f in result.files) {
          if (f.path != null) {
            _clips.add(File(f.path!));
          }
        }
        // Load first added clip if nothing loaded yet
        if (_currentClipIndex == -1 && _clips.isNotEmpty) {
          _currentClipIndex = 0;
          await _initializeVideoEditor(_clips[_currentClipIndex]);
        } else {
          setState(() {});
        }
      }
    } catch (e) {
      _showErrorSnackBar('选择视频失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _bgmPlayer.setFilePath(path);
        await _bgmPlayer.setVolume(_bgmVolume);
        await _bgmPlayer.setLoopMode(_bgmLoop ? LoopMode.one : LoopMode.off);
        setState(() {
          _bgmPath = path;
        });
      }
    } catch (e) {
      _showErrorSnackBar('选择音频失败: $e');
    }
  }

  Future<void> _syncBgmToVideoPosition() async {
    if (_bgmPath == null) return;
    final videoPos = _controller!.video.value.position;
    try {
      await _bgmPlayer.seek(videoPos);
    } catch (_) {}
  }

  Future<void> _togglePlayPauseSynced() async {
    if (_controller == null) return;
    if (_controller!.video.value.isPlaying) {
      _controller!.video.pause();
      if (_bgmPath != null) {
        await _bgmPlayer.pause();
      }
    } else {
      // Sync bgm to current position then play
      if (_bgmPath != null) {
        await _syncBgmToVideoPosition();
        await _bgmPlayer.play();
      }
      _controller!.video.play();
    }
    setState(() {});
  }

  Future<void> _seekTo(Duration position) async {
    await _controller!.video.seekTo(position);
    if (_bgmPath != null) {
      await _syncBgmToVideoPosition();
    }
    setState(() {});
  }

  Future<void> _initializeVideoEditor(File videoFile) async {
    try {
      final controller = VideoEditorController.file(
        videoFile,
        minDuration: const Duration(seconds: 1),
        maxDuration: const Duration(minutes: 10),
      );

      await controller.initialize(aspectRatio: 16 / 9);

      setState(() {
        _controller?.dispose();
        _controller = controller;
        // Reset editing properties
        _brightness = 0.0;
        _contrast = 1.0;
        _saturation = 1.0;
        _rotationAngle = 0;
      });
    } catch (e) {
      _showErrorSnackBar('视频初始化失败: $e');
    }
  }

  Future<void> _selectClip(int index) async {
    if (index < 0 || index >= _clips.length) return;
    setState(() {
      _isLoading = true;
    });
    try {
      _currentClipIndex = index;
      await _initializeVideoEditor(_clips[_currentClipIndex]);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeClip(int index) {
    if (index < 0 || index >= _clips.length) return;
    final removingCurrent = index == _currentClipIndex;
    _clips.removeAt(index);
    if (_clips.isEmpty) {
      _currentClipIndex = -1;
      _controller?.dispose();
      _controller = null;
    } else if (removingCurrent) {
      // load another clip
      _currentClipIndex = index.clamp(0, _clips.length - 1);
      _initializeVideoEditor(_clips[_currentClipIndex]);
    } else if (index < _currentClipIndex) {
      _currentClipIndex -= 1;
    }
    setState(() {});
  }

  void _moveClipUp(int index) {
    if (index <= 0 || index >= _clips.length) return;
    final tmp = _clips[index - 1];
    _clips[index - 1] = _clips[index];
    _clips[index] = tmp;
    if (_currentClipIndex == index) {
      _currentClipIndex = index - 1;
    } else if (_currentClipIndex == index - 1) {
      _currentClipIndex = index;
    }
    setState(() {});
  }

  void _moveClipDown(int index) {
    if (index < 0 || index >= _clips.length - 1) return;
    final tmp = _clips[index + 1];
    _clips[index + 1] = _clips[index];
    _clips[index] = tmp;
    if (_currentClipIndex == index) {
      _currentClipIndex = index + 1;
    } else if (_currentClipIndex == index + 1) {
      _currentClipIndex = index;
    }
    setState(() {});
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportVideo() async {
    if (_controller == null) return;

    // Guard: multi-clip export not implemented in current pipeline
    if (_clips.length > 1) {
      _showErrorSnackBar('暂不支持多视频合成导出（当前管线仅支持单个视频导出）');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/edited_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // Use video_compress for basic compression (note: filters not supported here)
      final inputPath = _controller!.file.path;
      final info = await VideoCompress.compressVideo(
        inputPath,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
        deleteOrigin: false,
        frameRate: 30,
      );

      if (info != null && info.path != null) {
        final compressed = File(info.path!);
        await compressed.copy(outputPath);
          setState(() {
            _exportProgress = 1.0;
          });
          _showSuccessSnackBar('视频导出成功！\n保存位置: $outputPath');
        } else {
          _showErrorSnackBar('视频导出失败');
        }
      
    } catch (e) {
      _showErrorSnackBar('导出过程中出错: $e');
    } finally {
      setState(() {
        _isExporting = false;
        _exportProgress = 0.0;
      });
    }
  }

  void _resetVideo() {
    if (_controller != null) {
      _controller!.video.seekTo(Duration.zero);
      setState(() {
        _brightness = 0.0;
        _contrast = 1.0;
        _saturation = 1.0;
        _rotationAngle = 0;
      });
    }
  }

  void _rotateVideo() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级视频编辑器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_controller != null) ...[
            IconButton(
              onPressed: _resetVideo,
              icon: const Icon(Icons.refresh),
              tooltip: '重置',
            ),
            IconButton(
              onPressed: _rotateVideo,
              icon: const Icon(Icons.rotate_right),
              tooltip: '旋转',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
              tooltip: '滤镜',
            ),
            IconButton(
              onPressed: _isExporting ? null : _exportVideo,
              icon: _isExporting 
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Icon(Icons.download),
              tooltip: '导出',
            ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _pickVideo,
        tooltip: '选择视频',
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.video_library),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '选择一个视频开始编辑',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Clips bar
        if (_clips.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.movie_creation_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('片段 (${_clips.length})'),
                    const Spacer(),
                    if (_clips.length > 1)
                      const Text('注意：导出暂不支持多片段合成', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _clips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final file = _clips[index];
                      final selected = index == _currentClipIndex;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _selectClip(index),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.movie, size: 18),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      file.path.split('/').last,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: '上移',
                              onPressed: () => _moveClipUp(index),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                            ),
                            IconButton(
                              tooltip: '下移',
                              onPressed: () => _moveClipDown(index),
                              icon: const Icon(Icons.arrow_downward, size: 18),
                            ),
                            IconButton(
                              tooltip: '移除',
                              onPressed: () => _removeClip(index),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        // Export progress
        if (_isExporting) ...[
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('正在导出视频...'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _exportProgress),
              ],
            ),
          ),
        ],
        
        // Video preview
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Transform.rotate(
                angle: _rotationAngle * pi / 180,
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                  child: CropGridViewer.preview(controller: _controller!),
                ),
              ),
            ),
          ),
        ),
        
        // Filters panel
        if (_showFilters) _buildFiltersPanel(),
        
        // Trim slider
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('视频裁剪', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TrimSlider(
                controller: _controller!,
                height: 60,
                horizontalMargin: 16,
              ),
            ],
          ),
        ),
        
        // Video info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('开始: ${_formatDuration(_controller!.startTrim)}'),
              Text('结束: ${_formatDuration(_controller!.endTrim)}'),
              Text('时长: ${_formatDuration(_controller!.endTrim - _controller!.startTrim)}'),
            ],
          ),
        ),
        
        // Control buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _seekTo(Duration.zero),
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
              ),
              IconButton(
                onPressed: _togglePlayPauseSynced,
                icon: Icon(
                  _controller!.video.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                iconSize: 48,
              ),
              IconButton(
                onPressed: () => _seekTo(_controller!.video.value.duration),
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
              ),
            ],
          ),
        ),
        // Audio controls
        if (_controller != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAudio,
                    icon: const Icon(Icons.library_music),
                    label: Text(_bgmPath == null ? '选择背景音乐' : '更换背景音乐'),
                  ),
                  const SizedBox(width: 12),
                  if (_bgmPath != null)
                    Text(
                      '已选中: ${_bgmPath!.split('/').last}',
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_bgmPath != null) Row(
                children: [
                  const Text('音量'),
                  Expanded(
                    child: Slider(
                      value: _bgmVolume,
                      min: 0,
                      max: 1,
                      onChanged: (v) async {
                        setState(() {
                          _bgmVolume = v;
                        });
                        await _bgmPlayer.setVolume(v);
                      },
                    ),
                  ),
                  Row(
                    children: [
                      const Text('循环'),
                      Switch(
                        value: _bgmLoop,
                        onChanged: (v) async {
                          setState(() {
                            _bgmLoop = v;
                          });
                          await _bgmPlayer.setLoopMode(v ? LoopMode.one : LoopMode.off);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('视频滤镜', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Brightness
          Row(
            children: [
              const SizedBox(width: 60, child: Text('亮度')),
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: -1.0,
                  max: 1.0,
                  divisions: 20,
                  label: _brightness.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _brightness = value;
                    });
                  },
                ),
              ),
            ],
          ),
          
          // Contrast
          Row(
            children: [
              const SizedBox(width: 60, child: Text('对比度')),
              Expanded(
                child: Slider(
                  value: _contrast,
                  min: 0.0,
                  max: 3.0,
                  divisions: 30,
                  label: _contrast.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _contrast = value;
                    });
                  },
                ),
              ),
            ],
          ),
          
          // Saturation
          Row(
            children: [
              const SizedBox(width: 60, child: Text('饱和度')),
              Expanded(
                child: Slider(
                  value: _saturation,
                  min: 0.0,
                  max: 3.0,
                  divisions: 30,
                  label: _saturation.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _saturation = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _buildColorMatrix() {
    // Build color matrix for brightness, contrast, and saturation
    return [
      _contrast, 0, 0, 0, _brightness * 255,
      0, _contrast, 0, 0, _brightness * 255,
      0, 0, _contrast, 0, _brightness * 255,
      0, 0, 0, 1, 0,
    ];
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }
}