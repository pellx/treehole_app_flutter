import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/version_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

class VersionDetailPage extends StatefulWidget {
  final VersionInfo version;

  const VersionDetailPage({super.key, required this.version});

  @override
  State<VersionDetailPage> createState() => _VersionDetailPageState();
}

class _VersionDetailPageState extends State<VersionDetailPage> {
  bool _downloading = false;

  /// APK 约 20MB+，给足超时避免中途断开却无提示
  static const _downloadTimeout = Duration(minutes: 5);

  Future<String?> _getApkUrl() async {
    final v = widget.version;
    if (v.downloadUrl.isEmpty) return null;
    final base = v.downloadUrl.endsWith('/')
        ? v.downloadUrl
        : '${v.downloadUrl}/';

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;
      const priority = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
      for (final abi in priority) {
        if (abis.contains(abi)) {
          return '${base}treehole-v${v.versionNumber}-$abi.apk';
        }
      }
    }
    return '${base}treehole-v${v.versionNumber}.apk';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _install() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final url = await _getApkUrl();
      if (url == null) {
        _toast('未配置下载地址');
        return;
      }
      debugPrint('[VersionDetail] 开始下载: $url');

      // 写入应用私有目录，避免 Android 10+ 无法写公共 Download
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/treehole_update.apk');
      await _downloadAndInstall(url, file);
    } catch (e, st) {
      debugPrint('[VersionDetail] 更新失败: $e\n$st');
      _toast('更新失败：$e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _downloadAndInstall(String url, File file) async {
    final resp = await http.get(Uri.parse(url)).timeout(_downloadTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint('[VersionDetail] HTTP ${resp.statusCode} url=$url');
      _toast('下载失败（HTTP ${resp.statusCode}）');
      return;
    }
    if (resp.bodyBytes.isEmpty) {
      _toast('下载失败：文件为空');
      return;
    }

    await file.writeAsBytes(resp.bodyBytes, flush: true);
    debugPrint('[VersionDetail] 已写入 ${file.path} (${resp.bodyBytes.length} bytes)');
    if (!mounted) return;

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('[VersionDetail] OpenFilex type=${result.type} message=${result.message}');
    if (result.type != ResultType.done) {
      _toast(result.message.isNotEmpty ? result.message : '无法打开安装包，请检查「安装未知应用」权限');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isCurrent = widget.version.versionNumber == VersionInfo.currentVersion;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: colors.postCreate.topBarBg,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: AppDimens.settingsBarHeight,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.common.barText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'v${widget.version.versionNumber} ${widget.version.title}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: colors.common.barText,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: AppDimens.postCreateSubmitMarginRight),
                      child: SizedBox(
                        height: AppDimens.postCreateSubmitHeight,
                        child: ElevatedButton(
                          onPressed: isCurrent || _downloading ? null : _install,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.postCreate.submitBg,
                            foregroundColor: colors.postCreate.submitText,
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDimens.postCreateSubmitHPadding,
                              vertical: 0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.postCreateSubmitRadius),
                            ),
                            textStyle: TextStyle(fontSize: AppDimens.postCreateSubmitFontSize),
                          ),
                          child: Text(
                            isCurrent ? '已是最新' : _downloading ? '下载中...' : '更新',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.version.description.isNotEmpty ? widget.version.description : '暂无详细说明',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.common.onSurface,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
