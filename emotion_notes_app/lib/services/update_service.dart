import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class UpdateService {
  static const String versionUrl = 'https://sjzwudi.top/version.json';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  /// 检查更新（仅 Android APK）
  Future<void> checkUpdate(
    BuildContext context, {
    bool showNoUpdate = false,
    bool silentIfLatest = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请在 Android 应用中检查更新')),
        );
      }
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);

      final response = await _dio.get(versionUrl);
      final versionInfo = response.data as Map<String, dynamic>;

      final serverVersionCode = (versionInfo['version_code'] as num).toInt();
      final versionName = versionInfo['version_name'] as String;
      final downloadUrl = versionInfo['download_url'] as String;
      final updateLog = versionInfo['update_log'] as String? ?? '新版本已发布';
      final forceUpdate = versionInfo['force_update'] as bool? ?? false;

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
          SnackBar(content: Text('已是最新版本 v${packageInfo.version}')),
        );
      }
    } catch (e) {
      print('[Update] 检查更新失败: $e');
      if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      } else if (!silentIfLatest && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    }
  }

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
      builder: (dialogContext) => PopScope(
        canPop: !forceUpdate,
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('稍后'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _downloadAndInstall(context, downloadUrl);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAndInstall(BuildContext context, String downloadUrl) async {
    if (!Platform.isAndroid) return;

    try {
      final installStatus = await Permission.requestInstallPackages.status;
      if (!installStatus.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要「安装未知应用」权限才能完成更新'),
              ),
            );
          }
          return;
        }
      }

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DownloadProgressDialog(
          downloadUrl: downloadUrl,
          dio: _dio,
        ),
      );
    } catch (e) {
      print('[Update] 下载更新失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }
}

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
  double _progress = 0;
  String _statusText = '准备下载...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/emotion_notes_update.apk';

      setState(() => _statusText = '正在下载...');

      await widget.dio.download(
        widget.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _progress = received / total;
              _statusText =
                  '下载中 ${(received / 1024 / 1024).toStringAsFixed(1)} MB / '
                  '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      setState(() => _statusText = '正在打开安装程序...');

      final result = await OpenFilex.open(savePath);

      if (!mounted) return;

      Navigator.of(context).pop();

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? '请手动安装：${result.message}'
                  : '无法自动安装，请在通知栏或文件管理器中完成安装',
            ),
          ),
        );
      }
    } catch (e) {
      print('[Update] 下载失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusText = '下载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasError) LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 16),
          Text(_statusText, textAlign: TextAlign.center),
        ],
      ),
      actions: _hasError
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ]
          : null,
    );
  }
}
