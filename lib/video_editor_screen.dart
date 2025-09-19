import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_editor/video_editor.dart';
import 'dart:io';

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoEditorController? _controller;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _initializeVideoEditor(File(result.files.single.path!));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeVideoEditor(File videoFile) async {
    try {
      final controller = VideoEditorController.file(
        videoFile,
        minDuration: const Duration(seconds: 1),
        maxDuration: const Duration(minutes: 5),
      );

      await controller.initialize(aspectRatio: 16 / 9);

      setState(() {
        _controller?.dispose();
        _controller = controller;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to initialize video editor: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _exportVideo() async {
    if (_controller == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Note: The export functionality might need additional setup
      // For now, we'll show a placeholder message
      _showSuccessSnackBar('Export functionality will be implemented');
    } catch (e) {
      _showErrorSnackBar('Failed to export video: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Editor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_controller != null)
            IconButton(
              onPressed: _isLoading ? null : _exportVideo,
              icon: const Icon(Icons.download),
              tooltip: 'Export Video',
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _pickVideo,
        tooltip: 'Pick Video',
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
              'Select a video to start editing',
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
        Expanded(
          child: CropGridViewer.preview(controller: _controller!),
        ),
        const SizedBox(height: 16),
        // Trim slider
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: TrimSlider(
            controller: _controller!,
            height: 60,
            horizontalMargin: 16,
          ),
        ),
        const SizedBox(height: 16),
        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => _controller!.video.seekTo(Duration.zero),
              icon: const Icon(Icons.skip_previous),
              iconSize: 32,
            ),
            IconButton(
              onPressed: () {
                if (_controller!.video.value.isPlaying) {
                  _controller!.video.pause();
                } else {
                  _controller!.video.play();
                }
                setState(() {});
              },
              icon: Icon(
                _controller!.video.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              iconSize: 48,
            ),
            IconButton(
              onPressed: () =>
                  _controller!.video.seekTo(_controller!.video.value.duration),
              icon: const Icon(Icons.skip_next),
              iconSize: 32,
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}