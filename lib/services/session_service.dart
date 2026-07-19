import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/device_fingerprint.dart';
import 'api.dart';
import 'avatar_storage.dart';
import 'binding_cache.dart';
import 'device_credential_store.dart';
import 'device_fingerprint.dart';
import 'storage.dart';

/// Session 管理服务
///
/// 统一管理 session 的申请和校验。
/// 调用时机：每次唤出输入框时（回复栏、注册页等）。
///
/// 逻辑：
///   1. 本地有 session → 校验有效性 → 有效则继续
///   2. 确认当前账号在本机仍为 live 绑定（active / unbind_pending）
///      - unbind_pending（解绑冷却期）仍保留令牌与 session，可继续使用
///      - 已 unbound（不在列表中）→ 清本地该账号令牌，尝试本机其他账户
///   3. 无 session 或无效 → 用 user_token + device_secret 申请
///      - DEVICE_NOT_BOUND（正式解绑后）→ 同上，清账号并尝试其他账户
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  /// 本机仍视为已登录的绑定状态（冷却期内不踢下线）
  static const _liveBindingStatuses = {'active', 'unbind_pending'};

  /// 正在进行的 ensureSession 调用，用于让并发调用者等待而非直接失败
  Completer<bool>? _pending;

  /// 最近一次 session 校验通过的时间；短期内重复调用跳过网络校验
  DateTime? _lastValidatedAt;
  static const _validationCacheTtl = Duration(minutes: 5);

  /// 使校验缓存失效（收到 401 等 session 失效信号时调用）
  void invalidate() => _lastValidatedAt = null;

  /// 确保当前有有效 session。
  ///
  /// 返回 true 表示 session 已就绪可用，false 表示无法获取 session。
  Future<bool> ensureSession() async {
    if (_pending != null) return _pending!.future;
    _pending = Completer<bool>();
    try {
      final result = await _ensureSessionInternal();
      _pending!.complete(result);
      return result;
    } catch (e) {
      _pending!.complete(false);
      rethrow;
    } finally {
      _pending = null;
    }
  }

  Future<bool> _ensureSessionInternal() async {
    final sessionId = await DeviceCredentialStore.getSessionId();
    final sessionSecret = await DeviceCredentialStore.getSessionSecret();

    if (sessionId != null && sessionSecret != null) {
      final lastValidated = _lastValidatedAt;
      final cacheHit = lastValidated != null &&
          DateTime.now().difference(lastValidated) < _validationCacheTtl;

      if (!cacheHit) {
        final validateResult = await ApiService.validateSession(
          sessionId: sessionId,
          sessionSecret: sessionSecret,
        );
        if (validateResult == null || !validateResult.valid) {
          _lastValidatedAt = null;
          await DeviceCredentialStore.clearSession();
        } else {
          _lastValidatedAt = DateTime.now();
          return _ensureCurrentAccountBoundOnDevice(
            sessionId: sessionId,
            sessionSecret: sessionSecret,
          );
        }
      } else {
        return _ensureCurrentAccountBoundOnDevice(
          sessionId: sessionId,
          sessionSecret: sessionSecret,
        );
      }
    }

    return _createSessionOrFailover();
  }

  /// 用当前/已知令牌申请 session；解绑则 login 复活或切其他账户
  Future<bool> _createSessionOrFailover() async {
    final userToken = await DeviceCredentialStore.getUserExternalToken();
    final deviceSecret = await DeviceCredentialStore.getDeviceSecret();

    if (userToken != null) {
      // 日常：有 secret 时走 session/create
      if (deviceSecret != null) {
        final ok = await _tryCreateSession(
          userToken: userToken,
          deviceSecret: deviceSecret,
        );
        if (ok) return true;
        // secret 失效或未绑定 → login 可复活并轮换 secret
        if (ApiService.lastError == 'DEVICE_NOT_BOUND' ||
            ApiService.lastError == 'DEVICE_SECRET_INVALID') {
          final loginOk = await loginWithToken(userToken);
          if (loginOk) return true;
        } else if (ApiService.lastError == 'DEVICE_SESSION_LOCKED') {
          return false;
        } else {
          return false;
        }
      } else {
        // 无本地 secret：直接 login
        final loginOk = await loginWithToken(userToken);
        if (loginOk) return true;
      }

      return _failoverAfterUnbound(
        failedToken: userToken,
        extraCandidates: const [],
      );
    }

    final known = await DeviceCredentialStore.getKnownUserTokens();
    if (known.isEmpty) return false;
    return _tryCandidateLogins(known);
  }

  /// session 有效时确认当前账号仍在本机 live 绑定列表中
  Future<bool> _ensureCurrentAccountBoundOnDevice({
    required int sessionId,
    required String sessionSecret,
  }) async {
    final accounts = await ApiService.listBoundAccounts(
      sessionId: sessionId,
      sessionSecret: sessionSecret,
    );
    // 网络失败时不误踢登录
    if (accounts == null) return true;

    // 仅 active / unbind_pending；冷却期内必须保留令牌与 session
    final live = accounts
        .where((a) => _liveBindingStatuses.contains(a.status))
        .toList();
    final tokens = live
        .map((a) => a.userToken.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    await DeviceCredentialStore.mergeKnownUserTokens(tokens);

    final current = await DeviceCredentialStore.getUserExternalToken();
    if (current != null) {
      final mine = live.where((a) => a.userToken == current);
      if (mine.isNotEmpty) {
        // active 与 unbind_pending 均保持登录态
        return true;
      }
      // 不在 live 列表：先 login 尝试复活绑定
      final revived = await loginWithToken(current);
      if (revived) return true;
    }

    final others = tokens.where((t) => t != current).toList();
    return _failoverAfterUnbound(
      failedToken: current,
      extraCandidates: others,
    );
  }

  Future<bool> _failoverAfterUnbound({
    required String? failedToken,
    required List<String> extraCandidates,
  }) async {
    await _evictCurrentAccount(failedToken);

    final known = await DeviceCredentialStore.getKnownUserTokens();
    final candidates = <String>{
      ...extraCandidates,
      ...known,
    };
    if (failedToken != null) candidates.remove(failedToken);

    if (candidates.isEmpty) {
      await _markLoggedOutFully();
      return false;
    }

    final ok = await _tryCandidateLogins(candidates.toList());
    if (!ok) await _markLoggedOutFully();
    return ok;
  }

  Future<bool> _tryCandidateLogins(List<String> tokens) async {
    for (final token in tokens) {
      final ok = await loginWithToken(token);
      if (ok) return true;
      if (ApiService.lastError == 'DEVICE_NOT_BOUND' ||
          ApiService.lastError == 'USER_NOT_FOUND') {
        await DeviceCredentialStore.removeKnownUserToken(token);
      }
    }
    return false;
  }

  Future<bool> _tryCreateSession({
    required String userToken,
    required String deviceSecret,
  }) async {
    final fingerprint = await DeviceFingerprintService.collect();
    final fingerprintHash = _computeFingerprintHash(fingerprint);

    final createResult = await ApiService.createSession(
      userToken: userToken,
      deviceSecret: deviceSecret,
      fingerprintHash: fingerprintHash,
    );

    if (createResult == null) return false;

    await DeviceCredentialStore.saveUserExternalToken(userToken);
    await DeviceCredentialStore.mergeKnownUserTokens([userToken]);
    await DeviceCredentialStore.clearAccountSessions();
    await DeviceCredentialStore.saveSessionId(createResult.sessionId);
    await DeviceCredentialStore.saveSessionSecret(createResult.sessionSecret);
    await DeviceCredentialStore.saveAccountSession(
      userToken,
      createResult.sessionId,
      createResult.sessionSecret,
    );
    _lastValidatedAt = DateTime.now();
    return true;
  }

  /// 本机已有 secret 时建绑（不轮换）；失败再降级 login
  Future<bool> _bindWithExistingSecret(String userToken) async {
    final secret = await DeviceCredentialStore.getDeviceSecret();
    if (secret == null) return loginWithToken(userToken);

    final fingerprint = await DeviceFingerprintService.collect();
    final fingerprintHash = _computeFingerprintHash(fingerprint);
    final bound = await ApiService.createBinding(
      userToken: userToken,
      fingerprintHash: fingerprintHash,
      deviceSecret: secret,
    );
    if (bound == null) {
      if (ApiService.lastError == 'DEVICE_SESSION_LOCKED') return false;
      // secret 无效等 → login 轮换
      if (ApiService.lastError == 'DEVICE_SECRET_INVALID' ||
          ApiService.lastError == 'DEVICE_NOT_FOUND' ||
          ApiService.lastError == 'FINGERPRINT_MISMATCH') {
        return loginWithToken(userToken);
      }
      // 其他建绑错误（含 transfer）直接失败，避免误轮换
      if (ApiService.lastError == 'TRANSFER_REQUIRED' ||
          ApiService.lastError == 'TRANSFER_INVALID' ||
          ApiService.lastError == 'REBIND_COOLDOWN') {
        return false;
      }
      return loginWithToken(userToken);
    }

    await DeviceCredentialStore.saveDeviceId(bound.deviceId);
    await DeviceCredentialStore.saveUserExternalToken(userToken);
    await DeviceCredentialStore.mergeKnownUserTokens([userToken]);
    return _tryCreateSession(userToken: userToken, deviceSecret: secret);
  }

  /// 已有账户登录本机：`POST /user/login`（轮换 secret）后再 `session/create`
  Future<bool> loginWithToken(String userToken) async {
    final token = userToken.trim();
    if (token.isEmpty) {
      ApiService.lastError = 'TOKEN_EMPTY';
      return false;
    }

    final fingerprint = await DeviceFingerprintService.collect();
    final fingerprintHash = _computeFingerprintHash(fingerprint);
    final result = await ApiService.login(
      userToken: token,
      fingerprintHash: fingerprintHash,
    );
    if (result == null) return false;

    invalidate();
    // login 下发的新 secret 必须覆盖本地，旧值已失效
    await DeviceCredentialStore.saveDeviceSecret(result.deviceSecret);
    await DeviceCredentialStore.saveUserExternalToken(token);
    await DeviceCredentialStore.mergeKnownUserTokens([token]);
    await DeviceCredentialStore.saveDeviceId(result.deviceId);
    await DeviceCredentialStore.clearSession();
    return _tryCreateSession(
      userToken: token,
      deviceSecret: result.deviceSecret,
    );
  }

  /// 切换到本机已绑定的其他账户。
  ///
  /// 一设备一 session：不可复用他户旧 session；走 session/create（必要时先建绑）。
  /// [displayNameHint] 列表里已知昵称，成功后立刻写入，再拉 profile 校正。
  Future<bool> switchToAccount(
    String userToken, {
    String? displayNameHint,
  }) async {
    final token = userToken.trim();
    if (token.isEmpty) {
      ApiService.lastError = 'TOKEN_EMPTY';
      return false;
    }

    final current =
        (await DeviceCredentialStore.getUserExternalToken())?.trim();
    if (current != null && current == token) {
      return ensureSession();
    }

    final deviceSecret = await DeviceCredentialStore.getDeviceSecret();
    if (deviceSecret != null) {
      final created = await _tryCreateSession(
        userToken: token,
        deviceSecret: deviceSecret,
      );
      if (created) {
        await _applySwitchedAccountDisplay(displayNameHint);
        return true;
      }

      final err = ApiService.lastError;
      if (err == 'DEVICE_SESSION_LOCKED') return false;
      if (err == 'DEVICE_NOT_BOUND') {
        final boundOk = await _bindWithExistingSecret(token);
        if (boundOk) await _applySwitchedAccountDisplay(displayNameHint);
        return boundOk;
      }
      final needLogin = err == 'DEVICE_SECRET_INVALID' ||
          err == 'DEVICE_NOT_FOUND' ||
          err == 'FINGERPRINT_MISMATCH';
      if (!needLogin) return false;
    }

    final loginOk = await loginWithToken(token);
    if (loginOk) await _applySwitchedAccountDisplay(displayNameHint);
    return loginOk;
  }

  /// 注册后：用现有 secret 建绑再申请 session
  Future<bool> activateAfterRegister(String userToken) async {
    return _bindWithExistingSecret(userToken.trim());
  }

  /// 切换成功后：清头像 → 立刻写入提示昵称 → 拉 profile 校正显示名
  Future<void> _applySwitchedAccountDisplay(String? displayNameHint) async {
    try {
      await AvatarStorage.clear();
    } catch (e) {
      debugPrint('[SessionService] 清除头像失败: $e');
    }

    final hint = displayNameHint?.trim() ?? '';
    await PostStorage.saveDisplayName(hint);

    final id = await DeviceCredentialStore.getSessionId();
    final secret = await DeviceCredentialStore.getSessionSecret();
    if (id == null || secret == null) return;

    final profile = await ApiService.getUserProfile(
      sessionId: id,
      sessionSecret: secret,
    );
    if (profile != null && profile.userDisplayId.isNotEmpty) {
      await PostStorage.saveDisplayName(profile.userDisplayId);
    }
  }

  /// 清当前账号本地凭证与展示缓存（保留 device_secret）
  Future<void> _evictCurrentAccount(String? token) async {
    invalidate();
    await DeviceCredentialStore.clearUserAccount();
    if (token != null && token.isNotEmpty) {
      await DeviceCredentialStore.removeKnownUserToken(token);
    }
    await PostStorage.saveDisplayName('');
    try {
      await AvatarStorage.clear();
    } catch (e) {
      debugPrint('[SessionService] 清除头像失败: $e');
    }
    try {
      if (Hive.isBoxOpen('binding_cache')) {
        await Hive.box('binding_cache').clear();
      }
      BindingCache.invalidateMemory();
    } catch (e) {
      debugPrint('[SessionService] 清除绑定缓存失败: $e');
    }
  }

  Future<void> _markLoggedOutFully() async {
    await PostStorage.setRegistered(false);
    await DeviceCredentialStore.saveKnownUserTokens([]);
    await DeviceCredentialStore.clearAccountSessions();
  }

  /// 计算设备指纹的 SHA-256 hex（每次 session 申请实时采集后计算，不持久化）
  ///
  /// 与后端 FingerprintService.computeHardwareHash() v2 保持一致：
  /// 仅含严格硬件身份字段；数组 sort 后用逗号拼接；所有值用 | 连接后 SHA-256。
  /// 可变字段（ROM 构建信息、systemFeatures、serialNumber 等）已排除，见 advice.md。
  static String _computeFingerprintHash(DeviceFingerprint fp) {
    final values = <String>[];

    void add(String value) => values.add(value);

    if (fp.platform == DevicePlatform.android && fp.android != null) {
      final a = fp.android!;

      add(a.build.board);
      add(a.build.brand);
      add(a.build.device);
      add(a.build.hardware);
      add(a.build.manufacturer);
      add(a.build.model);
      add(a.build.product);

      add(_sortedJoin(a.abi.supportedAbis));
      add(_sortedJoin(a.abi.supported32BitAbis));
      add(_sortedJoin(a.abi.supported64BitAbis));

      add(_boolString(a.hardware.isPhysicalDevice));
      add(a.hardware.physicalRamSize.toString());
      add(a.hardware.totalDiskSize.toString());
    } else if (fp.platform == DevicePlatform.ios && fp.ios != null) {
      final i = fp.ios!;

      add(i.device.model);
      add(i.device.modelName);
      add(i.device.systemName);
      add(i.device.localizedModel);
      add(_boolString(i.device.isPhysicalDevice));
      add(_boolString(i.device.isiOSAppOnMac));
      add(i.storage.physicalRamSize.toString());
      add(i.utsname.sysname);
      add(i.utsname.machine);
    } else {
      final jsonStr = jsonEncode(fp.toJson());
      return sha256.convert(utf8.encode(jsonStr)).toString();
    }

    return sha256.convert(utf8.encode(values.join('|'))).toString();
  }

  static String _sortedJoin(List<String> values) {
    final copy = [...values]..sort();
    return copy.join(',');
  }

  static String _boolString(bool value) => value ? 'true' : 'false';
}
