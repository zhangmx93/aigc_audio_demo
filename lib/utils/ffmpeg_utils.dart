import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import '../data/export_formats.dart';
import '../data/audio_tracks.dart';

class FFmpegUtils {
  // 常用视频比例常量
  static const double aspectRatio1_1 = 1.0;      // 正方形 1:1
  static const double aspectRatio4_3 = 4.0 / 3.0; // 传统电视 4:3
  static const double aspectRatio16_9 = 16.0 / 9.0; // 宽屏 16:9
  static const double aspectRatio9_16 = 9.0 / 16.0; // 竖屏 9:16
  static const double aspectRatio21_9 = 21.0 / 9.0; // 电影宽屏 21:9
  static const double aspectRatio3_4 = 3.0 / 4.0;  // 竖屏 3:4

  /// 获取视频尺寸信息
  static Future<({int width, int height})?> probeVideoSize(String path) async {
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
      if (kDebugMode) {
        print('FFmpegUtils: Probe video size error: $e');
      }
      return null;
    }
  }

  /// 将 asset 文件复制到临时目录
  static Future<String?> copyAssetToTemp(String assetPath) async {
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
        print('FFmpegUtils: Error copying asset: $e');
      }
      return null;
    }
  }

  /// 生成视频缩略图
  static Future<List<String>> generateThumbnails({
    required String inputPath,
    required Duration duration,
    double frameRate = 1.0, // 每秒生成一个缩略图
    int maxThumbnails = 60,
    Function(String thumbnailPath)? onThumbnailGenerated,
  }) async {
    final thumbnails = <String>[];
    
    try {
      final dir = await getTemporaryDirectory();
      final thumbsDir = Directory('${dir.path}/thumbs_${DateTime.now().millisecondsSinceEpoch}');
      if (!thumbsDir.existsSync()) thumbsDir.createSync(recursive: true);

      final totalSec = duration.inMilliseconds / 1000.0;
      if (totalSec <= 0) return thumbnails;
      
      // Calculate number of thumbnails based on frame rate
      final thumbnailCount = (totalSec * frameRate).round().clamp(1, maxThumbnails);
      final interval = totalSec / thumbnailCount;
      
      for (int i = 0; i < thumbnailCount; i++) {
        final ts = i * interval + (interval / 2); // Center of each interval
        final out = '${thumbsDir.path}/t_${i.toString().padLeft(3, '0')}.jpg';
        final cmd = "-y -ss ${ts.toStringAsFixed(3)} -i '$inputPath' -frames:v 1 -vf scale=320:-1 '$out'";
        final session = await FFmpegKit.execute(cmd);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(out).existsSync()) {
          thumbnails.add(out);
          onThumbnailGenerated?.call(out);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('FFmpegUtils: Thumbnails generation failed: $e');
      }
    }
    
    return thumbnails;
  }

  /// 清理缩略图文件
  static Future<void> clearThumbnails(List<String> thumbnailPaths) async {
    try {
      for (final path in thumbnailPaths) {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('FFmpegUtils: Error clearing thumbnails: $e');
      }
    }
  }

  /// 裁剪视频为指定比例
  static Future<({bool success, String? outputPath, String? errorMessage})> cropVideo({
    required String inputPath,
    required Duration startTime,
    required Duration duration,
    required ExportFormat exportFormat,
    required AudioTrackType audioTrackType,
    String? customAudioPath,
    double aspectRatio = 1.0, // 默认为正方形，1:1比例
  }) async {
    try {
      final size = await probeVideoSize(inputPath);
      if (size == null) {
        return (success: false, outputPath: null, errorMessage: '无法读取视频尺寸');
      }

      // 计算裁剪区域
      int cropWidth, cropHeight, x, y;
      
      final currentRatio = size.width / size.height;
      
      if (currentRatio > aspectRatio) {
        // 视频比目标比例更宽，需要裁剪宽度
        cropHeight = size.height;
        cropWidth = (size.height * aspectRatio).round();
        x = ((size.width - cropWidth) / 2).floor();
        y = 0;
      } else {
        // 视频比目标比例更高，需要裁剪高度
        cropWidth = size.width;
        cropHeight = (size.width / aspectRatio).round();
        x = 0;
        y = ((size.height - cropHeight) / 2).floor();
      }

      final dir = await getTemporaryDirectory();
      final formatData = ExportFormats.getByFormat(exportFormat);
      final outPath =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.${formatData.extension}';

      final filter = 'crop=$cropWidth:$cropHeight:$x:$y';
      final ss = (startTime.inMilliseconds / 1000.0).toStringAsFixed(3);
      final t = (duration.inMilliseconds / 1000.0).toStringAsFixed(3);
      
      // Build FFmpeg command with audio track support
      String audioParam;
      List<String> inputParams = ["-i '$inputPath'"];
      String filterComplex = "";
      
      switch (audioTrackType) {
        case AudioTrackType.original:
          audioParam = '-c:a copy';
          break;
        case AudioTrackType.silent:
          audioParam = '-an'; // Remove audio track
          break;
        case AudioTrackType.custom:
          if (customAudioPath != null) {
            String? actualAudioPath;
            
            // Check if it's an asset path or a file path
            if (customAudioPath.startsWith('assets/')) {
              // Copy asset to temporary directory
              actualAudioPath = await copyAssetToTemp(customAudioPath);
            } else if (File(customAudioPath).existsSync()) {
              // Use existing file path
              actualAudioPath = customAudioPath;
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
        cmd = "-y -i '$inputPath' -ss $ss -t $t -vf $filter -c:v libx264 -preset veryfast -crf 23 $audioParam '$outPath'";
      }

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      final success = ReturnCode.isSuccess(rc);

      if (success && File(outPath).existsSync()) {
        return (success: true, outputPath: outPath, errorMessage: null);
      } else {
        return (success: false, outputPath: null, errorMessage: '裁剪失败: ${rc?.getValue()}');
      }
    } catch (e) {
      return (success: false, outputPath: null, errorMessage: '执行错误: $e');
    }
  }

  /// 执行自定义 FFmpeg 命令
  static Future<({bool success, String? errorMessage})> executeCommand(String command) async {
    try {
      final session = await FFmpegKit.execute(command);
      final rc = await session.getReturnCode();
      final success = ReturnCode.isSuccess(rc);
      
      if (success) {
        return (success: true, errorMessage: null);
      } else {
        return (success: false, errorMessage: 'FFmpeg command failed: ${rc?.getValue()}');
      }
    } catch (e) {
      return (success: false, errorMessage: '执行错误: $e');
    }
  }

  /// 获取临时目录路径
  static Future<String> getTempDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// 裁剪视频为正方形（向后兼容方法）
  static Future<({bool success, String? outputPath, String? errorMessage})> cropCenterSquare({
    required String inputPath,
    required Duration startTime,
    required Duration duration,
    required ExportFormat exportFormat,
    required AudioTrackType audioTrackType,
    String? customAudioPath,
  }) async {
    return cropVideo(
      inputPath: inputPath,
      startTime: startTime,
      duration: duration,
      exportFormat: exportFormat,
      audioTrackType: audioTrackType,
      customAudioPath: customAudioPath,
      aspectRatio: 1.0, // 正方形比例
    );
  }

  /// 删除文件
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('FFmpegUtils: Error deleting file: $e');
      }
      return false;
    }
  }
}