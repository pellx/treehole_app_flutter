import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _registering = false;
  String? _error;

  Future<void> _register() async {
    setState(() { _registering = true; _error = null; });

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;
      String platform;
      String deviceModel;
      String osVersion;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        deviceId = android.id;
        platform = 'android';
        deviceModel = android.model;
        osVersion = android.version.release;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        deviceId = ios.identifierForVendor ?? 'ios-unknown';
        platform = 'ios';
        deviceModel = ios.model;
        osVersion = ios.systemVersion;
      } else {
        deviceId = 'unknown-${Random().nextInt(999999)}';
        platform = 'unknown';
        deviceModel = 'unknown';
        osVersion = '0';
      }

      final localToken = _generateToken();
      final ok = await ApiService.register(
        clientToken: localToken,
        deviceId: deviceId,
        platform: platform,
        deviceModel: deviceModel,
        osVersion: osVersion,
      );

      if (!mounted) return;

      if (ok) {
        await PostStorage.saveLocalToken(localToken);
        await PostStorage.setRegistered(true);
        Navigator.pop(context, true);
      } else {
        setState(() => _error = '注册失败，请检查网络后重试');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '注册失败：$e');
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  String _generateToken() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(999999)}-${r.nextInt(999999)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.postCreate.pageBg,
      appBar: AppBar(
        backgroundColor: colors.postCreate.pageBg,
        title: Text('账号', style: TextStyle(color: colors.common.onSurface)),
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.common.onSurface),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle_outlined, size: 80, color: colors.common.onSurface.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              Text(
                '注册账号',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.common.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '注册后即可发帖和评论',
                style: TextStyle(fontSize: 14, color: colors.postCreate.bottomHintText),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _registering ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.postCreate.submitBg,
                    foregroundColor: colors.postCreate.submitText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.postCreateButtonRadius),
                    ),
                  ),
                  child: _registering
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('一键注册', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
