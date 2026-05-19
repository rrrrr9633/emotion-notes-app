import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class UpdateService {
  // 与主 API 同域，避免 Android 9+ 禁止明文 HTTP
  static const String versionUrl = 'https://sjzwudi.top/version.json';
  
  final Dio _dio = Dio();
  
  /// 检查更新
  Future<void> checkUpdate(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      
      // 获取服务器版本信息
      final response = await _dio.get(versionUrl);
      final versionInfo = response.data;
      
      final serverVersionCode = versionInfo['version_code'] as int;
      final versionName = versionInfo['version_name'] as String;
      final downloadUrl = versionInfo['download_url'] as String;
      final updateLog = versionInfo['update_log'] as String;
      final forceUpdate = versionInfo['force_update'] as bool? ?? false;
      
      // 检查是否需要更新
      if (serverVersionCode > currentVersionCode) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            versionName: versionName,
            updateLog: updateLog,
            downloadUrl: downloadUrl,
            forceUpdate: forceUpdate,
          );
        }
      } else if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
      }
    } catch (e) {
      print('检查更新失败: $e');
      if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    }
  }
  
  /// 显示更新对话框
  void _showUpdateDialog(
    BuildContext context, {
    required String versionName,
    required String updateLog,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          title: Text('发现新版本 $versionName'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '更新内容：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(updateLog),
                if (forceUpdate) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '此版本为强制更新',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('稍后更新'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(context, downloadUrl);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 下载并安装APK
  Future<void> _downloadAndInstall(BuildContext context, String downloadUrl) async {
    try {
      // 请求存储权限
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要存储权限才能下载更新')),
            );
          }
          return;
        }
      }
      
      // 显示下载进度对话框
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DownloadProgressDialog(
          downloadUrl: downloadUrl,
          dio: _dio,
        ),
      );
    } catch (e) {
      print('下载更新失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
}

/// 下载进度对话框
class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final Dio dio;
  
  const _DownloadProgressDialog({
    required this.downloadUrl,
    required this.dio,
  });
  
  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _statusText = '准备下载...';
  
  @override
  void initState() {
    super.initState();
    _startDownload();
  }
  
  Future<void> _startDownload() async {
    try {
      // 获取下载目录
      final dir = await getExternalStorageDirectory();
      final savePath = '${dir!.path}/emotion_notes_update.apk';
      
      setState(() {
        _statusText = '正在下载...';
      });
      
      // 下载文件
      await widget.dio.download(
        widget.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _statusText = '下载中 ${(received / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB';
            });
          }
        },
      );
      
      setState(() {
        _statusText = '下载完成，准备安装...';
      });
      
      // 安装APK
      await _installApk(savePath);
      
    } catch (e) {
      print('下载失败: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
  
  Future<void> _installApk(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // 请求安装权限
        if (await Permission.requestInstallPackages.request().isGranted) {
          // 使用 install_plugin 安装
          // 注意：需要添加 install_plugin 依赖
          // 这里简化处理，实际需要使用 install_plugin 包
          
          // 临时方案：打开文件管理器让用户手动安装
          if (mounted) {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('下载完成'),
                content: Text('APK已下载到：\n$filePath\n\n请在文件管理器中找到并安装。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      print('安装失败: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('更新中'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 16),
          Text(_statusText),
        ],
      ),
    );
  }
}
