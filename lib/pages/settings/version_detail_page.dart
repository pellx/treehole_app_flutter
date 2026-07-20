import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/version_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// 尽量少权限的更新：
/// - 不申请存储权限：APK 写入应用临时目录
/// - 不声明 REQUEST_INSTALL_PACKAGES：用 FileProvider 调起系统安装器
/// - 失败则浏览器打开 APK 链接（仍只需 INTERNET）
class VersionDetailPage extends StatefulWidget {
  final VersionInfo version;

  const VersionDetailPage({super.key, required this.version});

  @override
  State<VersionDetailPage> createState() => _VersionDetailPageState();
}

class _VersionDetailPageState extends State<VersionDetailPage> {
  bool _downloading = false;

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

  /// 浏览器下载安装：应用侧除 INTERNET 外无额外权限
  Future<bool> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    debugPrint('[VersionDetail] 浏览器打开 url=$url ok=$ok');
    return ok;
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

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/treehole_update.apk');
      final opened = await _downloadAndInstall(url, file);
      if (opened) return;

      // 应用内调起失败：交给系统浏览器（零存储/安装声明）
      _toast('无法直接安装，已尝试用浏览器打开下载');
      final browserOk = await _openInBrowser(url);
      if (!browserOk) {
        _toast('请手动打开：$url');
      }
    } catch (e, st) {
      debugPrint('[VersionDetail] 更新失败: $e\n$st');
      final url = await _getApkUrl();
      if (url != null && await _openInBrowser(url)) {
        _toast('下载异常，已改用浏览器打开');
      } else {
        _toast('更新失败：$e');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// 返回是否已成功调起安装界面
  Future<bool> _downloadAndInstall(String url, File file) async {
    final resp = await http.get(Uri.parse(url)).timeout(_downloadTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint('[VersionDetail] HTTP ${resp.statusCode} url=$url');
      _toast('下载失败（HTTP ${resp.statusCode}）');
      return false;
    }
    if (resp.bodyBytes.isEmpty) {
      _toast('下载失败：文件为空');
      return false;
    }

    await file.writeAsBytes(resp.bodyBytes, flush: true);
    debugPrint('[VersionDetail] 已写入 ${file.path} (${resp.bodyBytes.length} bytes)');
    if (!mounted) return false;

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('[VersionDetail] OpenFilex type=${result.type} message=${result.message}');
    if (result.type == ResultType.done) return true;

    debugPrint('[VersionDetail] 应用内安装未成功: ${result.message}');
    return false;
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
