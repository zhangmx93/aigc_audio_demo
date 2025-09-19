import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_editor/video_editor.dart';
import 'dart:math';
import 'controllers/video_editor_controller.dart';
import 'ffmpeg_cropper.dart';

class GetxVideoEditor extends StatelessWidget {
  const GetxVideoEditor({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final controller = Get.put(VideoEditorGetxController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('GetX 视频编辑器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              Get.to(() => const FfmpegCropperScreen());
            },
            icon: const Icon(Icons.crop),
            tooltip: 'FFmpeg 裁剪',
          ),
          Obx(() => controller.videoController != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: controller.resetVideo,
                      icon: const Icon(Icons.refresh),
                      tooltip: '重置',
                    ),
                    IconButton(
                      onPressed: controller.rotateVideo,
                      icon: const Icon(Icons.rotate_right),
                      tooltip: '旋转',
                    ),
                    IconButton(
                      onPressed: controller.toggleFilters,
                      icon: Obx(() => Icon(controller.showFilters.value
                          ? Icons.filter_list_off
                          : Icons.filter_list)),
                      tooltip: '滤镜',
                    ),
                    IconButton(
                      onPressed: controller.isExporting.value ? null : controller.exportVideo,
                      icon: Obx(() => controller.isExporting.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download)),
                      tooltip: '导出',
                    ),
                  ],
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final ctrl = Get.find<VideoEditorGetxController>();
          if (!ctrl.isLoading.value) {
            ctrl.pickVideo();
          }
        },
        tooltip: '选择视频',
        child: Obx(() {
          final ctrl = Get.find<VideoEditorGetxController>();
          return ctrl.isLoading.value
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.video_library);
        }),
      ),
    );
  }

  Widget _buildBody() {
    return GetBuilder<VideoEditorGetxController>(
      builder: (controller) {
        return Obx(() {
          if (controller.isLoading.value && controller.videoController == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.videoController == null) {
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
              // Export progress
              Obx(() => controller.isExporting.value
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('正在导出视频...'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: controller.exportProgress.value),
                        ],
                      ),
                    )
                  : const SizedBox.shrink()),

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
                    child: Obx(() => Transform.rotate(
                          angle: controller.rotationAngle.value * pi / 180,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(controller.buildColorMatrix()),
                            child: CropGridViewer.preview(controller: controller.videoController!),
                          ),
                        )),
                  ),
                ),
              ),

              // Filters panel
              Obx(() => controller.showFilters.value 
                  ? _buildFiltersPanel(controller)
                  : const SizedBox.shrink()),

              // Trim slider
              Container(
                // margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('视频裁剪', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TrimSlider(
                      controller: controller.videoController!,
                      height: 60,
                      horizontalMargin: 16
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
                    Text('开始: ${controller.formatDuration(controller.videoController!.startTrim)}'),
                    Text('结束: ${controller.formatDuration(controller.videoController!.endTrim)}'),
                    Text('时长: ${controller.formatDuration(controller.videoController!.endTrim - controller.videoController!.startTrim)}'),
                  ],
                ),
              ),

              // Control buttons
              Container(
                // padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: controller.seekToStart,
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 32,
                    ),
                    GetBuilder<VideoEditorGetxController>(
                      builder: (ctrl) {
                        return IconButton(
                          onPressed: ctrl.togglePlayPause,
                          icon: Obx(() {
                            final isPlaying = ctrl.videoController?.video.value.isPlaying ?? false;
                            return Icon(
                              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            );
                          }),
                          iconSize: 48,
                        );
                      },
                    ),
                    IconButton(
                      onPressed: controller.seekToEnd,
                      icon: const Icon(Icons.skip_next),
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildFiltersPanel(VideoEditorGetxController controller) {
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
                child: Obx(() => Slider(
                      value: controller.brightness.value,
                      min: -1.0,
                      max: 1.0,
                      divisions: 20,
                      label: controller.brightness.value.toStringAsFixed(1),
                      onChanged: controller.updateBrightness,
                    )),
              ),
            ],
          ),

          // Contrast
          Row(
            children: [
              const SizedBox(width: 60, child: Text('对比度')),
              Expanded(
                child: Obx(() => Slider(
                      value: controller.contrast.value,
                      min: 0.0,
                      max: 3.0,
                      divisions: 30,
                      label: controller.contrast.value.toStringAsFixed(1),
                      onChanged: controller.updateContrast,
                    )),
              ),
            ],
          ),

          // Saturation
          Row(
            children: [
              const SizedBox(width: 60, child: Text('饱和度')),
              Expanded(
                child: Obx(() => Slider(
                      value: controller.saturation.value,
                      min: 0.0,
                      max: 3.0,
                      divisions: 30,
                      label: controller.saturation.value.toStringAsFixed(1),
                      onChanged: controller.updateSaturation,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}