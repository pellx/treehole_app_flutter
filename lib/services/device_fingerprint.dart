import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart' as dpi;
import '../models/device_fingerprint.dart';

/// 设备指纹服务 — 收集全部设备信息，返回结构化数据
class DeviceFingerprintService {
  static const _salt = 'treehole_device_fingerprint_v1';

  /// 收集所有设备信息，返回结构化指纹
  static Future<DeviceFingerprint> collect() async {
    final plugin = dpi.DeviceInfoPlugin();

    if (Platform.isAndroid) {
      return _collectAndroid(await plugin.androidInfo);
    } else if (Platform.isIOS) {
      return _collectIOS(await plugin.iosInfo);
    }
    return DeviceFingerprint.unknown();
  }

  /// 生成不可逆指纹 hash（SHA-256）
  static Future<String> generate() async {
    final fp = await collect();
    final json = jsonEncode(fp.toJson());
    final hash = sha256.convert(utf8.encode('$_salt:$json'));
    return hash.toString();
  }

  // ── Android ──

  static DeviceFingerprint _collectAndroid(dynamic info) {
    return DeviceFingerprint.android(AndroidFingerprint(
      build: AndroidBuildInfo(
        board: info.board,
        bootloader: info.bootloader,
        brand: info.brand,
        device: info.device,
        display: info.display,
        fingerprint: info.fingerprint,
        hardware: info.hardware,
        host: info.host,
        id: info.id,
        manufacturer: info.manufacturer,
        model: info.model,
        product: info.product,
        name: info.name,
        tags: info.tags,
        type: info.type,
      ),
      version: AndroidVersionInfo(
        baseOS: info.version.baseOS,
        codename: info.version.codename,
        incremental: info.version.incremental,
        previewSdkInt: info.version.previewSdkInt,
        release: info.version.release,
        sdkInt: info.version.sdkInt,
        securityPatch: info.version.securityPatch,
      ),
      abi: AndroidAbiInfo(
        supported32BitAbis: info.supported32BitAbis,
        supported64BitAbis: info.supported64BitAbis,
        supportedAbis: info.supportedAbis,
      ),
      hardware: AndroidHardwareInfo(
        isPhysicalDevice: info.isPhysicalDevice,
        isLowRamDevice: info.isLowRamDevice,
        freeDiskSize: info.freeDiskSize,
        totalDiskSize: info.totalDiskSize,
        physicalRamSize: info.physicalRamSize,
        availableRamSize: info.availableRamSize,
        serialNumber: info.serialNumber,
        systemFeatures: info.systemFeatures,
      ),
    ));
  }

  // ── iOS ──

  static DeviceFingerprint _collectIOS(dynamic info) {
    return DeviceFingerprint.ios(IosFingerprint(
      device: IosDeviceInfo(
        name: info.name,
        systemName: info.systemName,
        systemVersion: info.systemVersion,
        model: info.model,
        modelName: info.modelName,
        localizedModel: info.localizedModel,
        identifierForVendor: info.identifierForVendor,
        isPhysicalDevice: info.isPhysicalDevice,
        isiOSAppOnMac: info.isiOSAppOnMac,
      ),
      storage: IosStorageInfo(
        freeDiskSize: info.freeDiskSize,
        totalDiskSize: info.totalDiskSize,
        physicalRamSize: info.physicalRamSize,
        availableRamSize: info.availableRamSize,
      ),
      utsname: IosUtsnameInfo(
        sysname: info.utsname.sysname,
        nodename: info.utsname.nodename,
        release: info.utsname.release,
        version: info.utsname.version,
        machine: info.utsname.machine,
      ),
    ));
  }
}
