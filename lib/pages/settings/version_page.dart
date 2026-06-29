import 'package:flutter/material.dart';

import '../../models/version_info.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

class VersionPage extends StatefulWidget {
  const VersionPage({super.key});

  @override
  State<VersionPage> createState() => _VersionPageState();
}

class _VersionPageState extends State<VersionPage> {
  List<VersionInfo> _versions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 先显示缓存
    final cached = PostStorage.getCachedVersions();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _versions = cached;
        _loading = false;
      });
    }

    // 再从 API 拉最新
    final remote = await ApiService.getAllVersions();
    if (mounted) {
      if (remote.isNotEmpty) {
        await PostStorage.saveVersions(remote);
        setState(() {
          _versions = remote;
          _loading = false;
          _error = null;
        });
      } else if (cached.isEmpty) {
        setState(() {
          _loading = false;
          _error = '加载失败，请检查网络';
        });
      }
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('更新日志'),
        backgroundColor: colors.common.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: colors.common.onSurface)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardHPadding, vertical: 12),
                  itemCount: _versions.length,
                  itemBuilder: (_, i) {
                    final v = _versions[i];
                    final isLatest = i == 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.common.surface,
                        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                        border: isLatest
                            ? Border.all(color: colors.common.green, width: 1.5)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'v${v.versionNumber}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colors.common.onSurface,
                                  ),
                                ),
                                if (isLatest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.common.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('最新', style: TextStyle(fontSize: 11, color: Colors.white)),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  _formatDate(v.releaseDate),
                                  style: TextStyle(fontSize: 12, color: colors.common.trailingIcon),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              v.changelog,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.common.onSurface,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
