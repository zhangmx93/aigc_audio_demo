import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'permission_manager.dart';

class GalleryService {
  /// 保存视频文件到相册
  static Future<bool> saveVideoToGallery(String filePath) async {
    try {
      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          print('文件不存在: $filePath');
        }
        return false;
      }

      // 请求相册权限
      final hasPermission = await PermissionManager.requestAllPermissions();
      if (!hasPermission) {
        if (kDebugMode) {
          print('没有相册权限');
          final statusDesc = await PermissionManager.getPermissionStatusDescription();
          print('权限状态:\n$statusDesc');
        }
        return false;
      }

      // 保存到相册
      final AssetEntity? result = await PhotoManager.editor.saveVideo(
        file,
        title: _generateFileName(filePath),
      );

      if (result != null) {
        if (kDebugMode) {
          print('视频已保存到相册: ${result.id}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('保存视频失败');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存视频到相册时发生错误: $e');
      }
      return false;
    }
  }

  /// 生成文件名
  static String _generateFileName(String filePath) {
    final fileName = filePath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'video_editor_${timestamp}_$fileName';
  }

  /// 检查是否有相册权限
  static Future<bool> hasPermission() async {
    return await PermissionManager.checkPermissions();
  }
}