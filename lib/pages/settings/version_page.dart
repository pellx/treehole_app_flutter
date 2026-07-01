import 'package:flutter/material.dart';

import '../../models/version_info.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/version_card.dart';
import 'version_detail_page.dart';

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
    final cached = PostStorage.getCachedVersions();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _versions = cached;
        _loading = false;
      });
    }
    final remote = await ApiService.getAllVersions();
    if (mounted) {
      if (remote.isNotEmpty) {
        await PostStorage.saveVersions(remote);
        setState(() { _versions = remote; _loading = false; _error = null; });
      } else if (cached.isEmpty) {
        setState(() { _loading = false; _error = '加载失败'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: colors.common.trailingIcon)));
    }
    if (_versions.isEmpty) {
      return Center(child: Text('暂无版本记录', style: TextStyle(color: colors.common.trailingIcon)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardHPadding, vertical: 12),
      itemCount: _versions.length,
      itemBuilder: (_, i) => VersionCard(
        version: _versions[i],
        isLatest: i == 0,
        onTap: () => Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => VersionDetailPage(version: _versions[i]),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        )),
      ),
    );
  }
}
