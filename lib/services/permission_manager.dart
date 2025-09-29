import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PermissionManager {
  /// 请求所有必要的权限
  static Future<bool> requestAllPermissions() async {
    try {
      if (kDebugMode) {
        print('开始请求权限...');
      }

      // 1. 请求Photo Manager权限
      final photoManagerPermission = await PhotoManager.requestPermissionExtend();
      if (photoManagerPermission != PermissionState.authorized) {
        if (kDebugMode) {
          print('Photo Manager权限被拒绝: $photoManagerPermission');
        }
        return false;
      }

      // 2. 根据平台请求特定权限
      if (Platform.isAndroid) {
        return await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('请求权限时发生错误: $e');
      }
      return false;
    }
  }

  /// 请求Android权限
  static Future<bool> _requestAndroidPermissions() async {
    final permissions = <Permission>[];
    
    // Android 13+ (API 33+) 使用新的媒体权限
    if (await _getAndroidVersion() >= 33) {
      permissions.addAll([
        Permission.videos,
        Permission.photos,
        Permission.audio,
      ]);
    } else {
      // Android 12及以下使用存储权限
      permissions.addAll([
        Permission.storage,
        Permission.manageExternalStorage,
      ]);
    }

    // 请求权限
    final Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // 检查是否所有权限都被授予
    bool allGranted = true;
    for (final entry in statuses.entries) {
      if (!entry.value.isGranted) {
        if (kDebugMode) {
          print('Android权限被拒绝: ${entry.key} -> ${entry.value}');
        }
        allGranted = false;
      }
    }

    return allGranted;
  }

  /// 请求iOS权限
  static Future<bool> _requestIOSPermissions() async {
    final permissions = [
      Permission.photos,
      Permission.photosAddOnly,
    ];

    final Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // 检查是否至少有读取权限
    final photosStatus = statuses[Permission.photos];
    final addOnlyStatus = statuses[Permission.photosAddOnly];
    
    if (photosStatus?.isGranted == true || addOnlyStatus?.isGranted == true) {
      return true;
    }

    if (kDebugMode) {
      print('iOS权限被拒绝: photos=$photosStatus, addOnly=$addOnlyStatus');
    }
    return false;
  }

  /// 检查权限状态
  static Future<bool> checkPermissions() async {
    try {
      // 检查Photo Manager权限
      final photoManagerPermission = await PhotoManager.requestPermissionExtend();
      if (photoManagerPermission != PermissionState.authorized) {
        return false;
      }

      if (Platform.isAndroid) {
        return await _checkAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _checkIOSPermissions();
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('检查权限时发生错误: $e');
      }
      return false;
    }
  }

  /// 检查Android权限状态
  static Future<bool> _checkAndroidPermissions() async {
    if (await _getAndroidVersion() >= 33) {
      return await Permission.videos.isGranted && await Permission.photos.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }

  /// 检查iOS权限状态
  static Future<bool> _checkIOSPermissions() async {
    final photosStatus = await Permission.photos.status;
    final addOnlyStatus = await Permission.photosAddOnly.status;
    
    return photosStatus.isGranted || addOnlyStatus.isGranted;
  }

  /// 获取Android SDK版本
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // 这里可以通过平台通道获取SDK版本，简单起见使用默认值
      return 33; // 假设为Android 13+
    } catch (e) {
      return 30; // 默认为较低版本
    }
  }

  /// 显示权限设置对话框
  static Future<void> showPermissionDialog(String message) async {
    if (kDebugMode) {
      print('权限提示: $message');
    }
    // 这里可以显示一个对话框引导用户去设置页面
    await openAppSettings();
  }

  /// 获取权限状态描述
  static Future<String> getPermissionStatusDescription() async {
    final buffer = StringBuffer();
    
    // Photo Manager状态
    final photoManagerState = await PhotoManager.requestPermissionExtend();
    buffer.writeln('Photo Manager: ${photoManagerState.name}');
    
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      final videosStatus = await Permission.videos.status;
      final photosStatus = await Permission.photos.status;
      
      buffer.writeln('存储权限: ${storageStatus.name}');
      buffer.writeln('视频权限: ${videosStatus.name}');
      buffer.writeln('照片权限: ${photosStatus.name}');
    } else if (Platform.isIOS) {
      final photosStatus = await Permission.photos.status;
      final addOnlyStatus = await Permission.photosAddOnly.status;
      
      buffer.writeln('照片库权限: ${photosStatus.name}');
      buffer.writeln('仅添加权限: ${addOnlyStatus.name}');
    }
    
    return buffer.toString();
  }
}