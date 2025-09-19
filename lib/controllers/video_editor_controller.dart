import 'package:get/get.dart';
import 'package:video_editor/video_editor.dart' as video_editor;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:io';

class VideoEditorGetxController extends GetxController {
  // Observable variables
  final Rx<video_editor.VideoEditorController?> _videoController = Rx<video_editor.VideoEditorController?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isExporting = false.obs;
  final RxDouble exportProgress = 0.0.obs;
  final RxBool showFilters = false.obs;
  
  // Filter properties
  final RxDouble brightness = 0.0.obs;
  final RxDouble contrast = 1.0.obs;
  final RxDouble saturation = 1.0.obs;
  final RxInt rotationAngle = 0.obs;
  
  // Getters
  video_editor.VideoEditorController? get videoController => _videoController.value;
  
  @override
  void onClose() {
    _videoController.value?.dispose();
    super.onClose();
  }
  
  // Pick video from file system
  Future<void> pickVideo() async {
    try {
      isLoading.value = true;
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _initializeVideoEditor(File(result.files.single.path!));
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '选择视频失败: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  // Initialize video editor
  Future<void> _initializeVideoEditor(File videoFile) async {
    try {
      final controller = video_editor.VideoEditorController.file(
        videoFile,
        minDuration: const Duration(seconds: 1),
        maxDuration: const Duration(minutes: 10),
      );

      await controller.initialize(aspectRatio: 16 / 9);

      // Dispose previous controller
      _videoController.value?.dispose();
      _videoController.value = controller;
      
      // Reset editing properties
      resetFilters();
    } catch (e) {
      Get.snackbar(
        '错误',
        '视频初始化失败: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }
  
  // Export video with current settings
  Future<void> exportVideo() async {
    if (_videoController.value == null) return;

    try {
      isExporting.value = true;
      exportProgress.value = 0.0;

      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/edited_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      final inputPath = _videoController.value!.file.path;
      final startTime = _videoController.value!.startTrim.inSeconds;
      final duration = (_videoController.value!.endTrim - _videoController.value!.startTrim).inSeconds;
      
      // Use video_compress for basic video compression
      // Note: video_compress has limited filter support compared to FFmpeg
      final mediaInfo = await VideoCompress.compressVideo(
        inputPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );
      
      if (mediaInfo != null) {
        // Move the compressed file to our desired output path
        final compressedFile = File(mediaInfo.path!);
        final outputFile = File(outputPath);
        await compressedFile.copy(outputPath);
        
        exportProgress.value = 1.0;
        Get.snackbar(
          '成功',
          '视频导出成功！\n保存位置: $outputPath',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          '错误',
          '视频导出失败',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
      }
      
    } catch (e) {
      Get.snackbar(
        '错误',
        '导出过程中出错: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isExporting.value = false;
      exportProgress.value = 0.0;
    }
  }
  
  // Reset video and filters
  void resetVideo() {
    if (_videoController.value != null) {
      _videoController.value!.video.seekTo(Duration.zero);
      resetFilters();
    }
  }
  
  // Reset all filter values
  void resetFilters() {
    brightness.value = 0.0;
    contrast.value = 1.0;
    saturation.value = 1.0;
    rotationAngle.value = 0;
  }
  
  // Rotate video by 90 degrees
  void rotateVideo() {
    rotationAngle.value = (rotationAngle.value + 90) % 360;
  }
  
  // Toggle filters panel
  void toggleFilters() {
    showFilters.value = !showFilters.value;
  }
  
  // Update brightness
  void updateBrightness(double value) {
    brightness.value = value;
  }
  
  // Update contrast
  void updateContrast(double value) {
    contrast.value = value;
  }
  
  // Update saturation
  void updateSaturation(double value) {
    saturation.value = value;
  }
  
  // Build color matrix for filters
  List<double> buildColorMatrix() {
    return [
      contrast.value, 0, 0, 0, brightness.value * 255,
      0, contrast.value, 0, 0, brightness.value * 255,
      0, 0, contrast.value, 0, brightness.value * 255,
      0, 0, 0, 1, 0,
    ];
  }
  
  // Format duration for display
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }
  
  // Play/pause video
  void togglePlayPause() {
    if (_videoController.value != null) {
      if (_videoController.value!.video.value.isPlaying) {
        _videoController.value!.video.pause();
      } else {
        _videoController.value!.video.play();
      }
    }
  }
  
  // Seek to start
  void seekToStart() {
    _videoController.value?.video.seekTo(Duration.zero);
  }
  
  // Seek to end
  void seekToEnd() {
    if (_videoController.value != null) {
      _videoController.value!.video.seekTo(_videoController.value!.video.value.duration);
    }
  }
}