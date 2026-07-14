import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api.dart';
import '../../services/storage.dart';
import '../../services/device_credential_store.dart';
import '../../theme/app_colors.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final _nameController = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;
  String _externalToken = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = PostStorage.getDisplayName() ?? PostStorage.getUserName();
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadExternalToken();
  }

  Future<void> _loadExternalToken() async {
    final token = await DeviceCredentialStore.getUserExternalToken();
    if (mounted) {
      setState(() {
        _externalToken = token ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final userToken = await DeviceCredentialStore.getUserExternalToken();
      if (userToken == null) {
        setState(() => _error = '会话异常');
        return;
      }

      final result = await ApiService.rename(
        userExternalToken: userToken,
        newName: name,
      );

      if (!mounted) return;

      if (result != null) {
        await PostStorage.saveDisplayName(result);
        _nameController.text = result;
        setState(() => _editing = false);
      } else {
        setState(() => _error = ApiService.lastError ?? '改名失败');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '网络异常：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final displayName = PostStorage.getDisplayName() ?? PostStorage.getUserName();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('用户', style: TextStyle(color: onSurface, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // 头像
            CircleAvatar(
              radius: 50,
              backgroundColor: colors.common.idTint.withValues(alpha: 0.2),
              backgroundImage: const AssetImage('assets/420px-Transparent_Akkarin.jpg'),
            ),
            const SizedBox(height: 28),
            // 用户名区域
            if (_editing) ...[
              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 100,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
                decoration: InputDecoration(
                  hintText: '输入新名字',
                  counterText: '',
                  filled: true,
                  fillColor: onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => setState(() {
                      _editing = false;
                      _error = null;
                      _nameController.text = displayName;
                    }),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: (_saving || _nameController.text.trim().isEmpty) ? null : _saveName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.postCreate.submitBg,
                      foregroundColor: colors.postCreate.submitText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('确认'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFE57373)),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              GestureDetector(
                onTap: () => setState(() {
                  _editing = true;
                  _error = null;
                  _nameController.text = displayName;
                }),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.edit_outlined, size: 18, color: onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
            // 账户信息
            _infoTile('用户标识', _externalToken.length > 16
                ? '${_externalToken.substring(0, 16)}...'
                : _externalToken, onSurface, onTap: () {
              Clipboard.setData(ClipboardData(text: _externalToken));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制用户标识'), duration: Duration(seconds: 1)),
              );
            }),
            const Divider(height: 1),
            _infoTile('注册时间', '—', onSurface),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, Color onSurface, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: onSurface.withValues(alpha: 0.6))),
            Row(
              children: [
                Text(value, style: TextStyle(fontSize: 15, color: onSurface)),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.copy, size: 14, color: onSurface.withValues(alpha: 0.3)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
