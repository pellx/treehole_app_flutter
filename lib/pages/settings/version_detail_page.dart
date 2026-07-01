import 'dart:io';

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

  Future<void> _install() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final url = await _getApkUrl();
      if (url == null) return;

      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      if (!await dir.exists() && Platform.isAndroid) {
        // 降级
        final tmp = await getApplicationDocumentsDirectory();
        final file = File('${tmp.path}/treehole_update.apk');
        await _downloadAndInstall(url, file);
        return;
      }
      final file = File('${dir.path}/treehole_update.apk');
      await _downloadAndInstall(url, file);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _downloadAndInstall(String url, File file) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode < 200 || resp.statusCode >= 300) return;
    await file.writeAsBytes(resp.bodyBytes);
    if (!mounted) return;
    await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
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
