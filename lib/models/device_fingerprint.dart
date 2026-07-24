/// 设备指纹数据模型

// ── Android 子结构 ──

class AndroidBuildInfo {
  final String board;
  final String bootloader;
  final String brand;
  final String device;
  final String display;
  final String fingerprint;
  final String hardware;
  final String host;
  final String id;
  final String manufacturer;
  final String model;
  final String product;
  final String name;
  final String tags;
  final String type;

  const AndroidBuildInfo({
    required this.board,
    required this.bootloader,
    required this.brand,
    required this.device,
    required this.display,
    required this.fingerprint,
    required this.hardware,
    required this.host,
    required this.id,
    required this.manufacturer,
    required this.model,
    required this.product,
    required this.name,
    required this.tags,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'board': board, 'bootloader': bootloader, 'brand': brand,
    'device': device, 'display': display, 'fingerprint': fingerprint,
    'hardware': hardware, 'host': host, 'id': id,
    'manufacturer': manufacturer, 'model': model, 'product': product,
    'name': name, 'tags': tags, 'type': type,
  };
}

class AndroidVersionInfo {
  final String? baseOS;
  final String codename;
  final String incremental;
  final int? previewSdkInt;
  final String release;
  final int sdkInt;
  final String? securityPatch;

  const AndroidVersionInfo({
    this.baseOS,
    required this.codename,
    required this.incremental,
    this.previewSdkInt,
    required this.release,
    required this.sdkInt,
    this.securityPatch,
  });

  Map<String, dynamic> toJson() => {
    'baseOS': baseOS, 'codename': codename,
    'incremental': incremental, 'previewSdkInt': previewSdkInt,
    'release': release, 'sdkInt': sdkInt,
    'securityPatch': securityPatch,
  };
}

class AndroidAbiInfo {
  final List<String> supported32BitAbis;
  final List<String> supported64BitAbis;
  final List<String> supportedAbis;

  const AndroidAbiInfo({
    required this.supported32BitAbis,
    required this.supported64BitAbis,
    required this.supportedAbis,
  });

  Map<String, dynamic> toJson() => {
    'supported32BitAbis': supported32BitAbis,
    'supported64BitAbis': supported64BitAbis,
    'supportedAbis': supportedAbis,
  };
}

class AndroidHardwareInfo {
  final bool isPhysicalDevice;
  final bool isLowRamDevice;
  final int freeDiskSize;
  final int totalDiskSize;
  final int physicalRamSize;
  final int availableRamSize;
  final String serialNumber;
  final List<String> systemFeatures;

  const AndroidHardwareInfo({
    required this.isPhysicalDevice,
    required this.isLowRamDevice,
    required this.freeDiskSize,
    required this.totalDiskSize,
    required this.physicalRamSize,
    required this.availableRamSize,
    required this.serialNumber,
    required this.systemFeatures,
  });

  Map<String, dynamic> toJson() => {
    'isPhysicalDevice': isPhysicalDevice,
    'isLowRamDevice': isLowRamDevice,
    'freeDiskSize': freeDiskSize,
    'totalDiskSize': totalDiskSize,
    'physicalRamSize': physicalRamSize,
    'availableRamSize': availableRamSize,
    'serialNumber': serialNumber,
    'systemFeatures': systemFeatures,
  };
}

// ── Android 汇总 ──

class AndroidFingerprint {
  final AndroidBuildInfo build;
  final AndroidVersionInfo version;
  final AndroidAbiInfo abi;
  final AndroidHardwareInfo hardware;

  const AndroidFingerprint({
    required this.build,
    required this.version,
    required this.abi,
    required this.hardware,
  });

  Map<String, dynamic> toJson() => {
    'build': build.toJson(),
    'version': version.toJson(),
    'abi': abi.toJson(),
    'hardware': hardware.toJson(),
  };
}

// ── iOS 子结构 ──

class IosDeviceInfo {
  final String name;
  final String systemName;
  final String systemVersion;
  final String model;
  final String modelName;
  final String localizedModel;
  final String? identifierForVendor;
  final bool isPhysicalDevice;
  final bool isiOSAppOnMac;

  const IosDeviceInfo({
    required this.name,
    required this.systemName,
    required this.systemVersion,
    required this.model,
    required this.modelName,
    required this.localizedModel,
    this.identifierForVendor,
    required this.isPhysicalDevice,
    required this.isiOSAppOnMac,
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'systemName': systemName,
    'systemVersion': systemVersion, 'model': model,
    'modelName': modelName, 'localizedModel': localizedModel,
    'identifierForVendor': identifierForVendor,
    'isPhysicalDevice': isPhysicalDevice,
    'isiOSAppOnMac': isiOSAppOnMac,
  };
}

class IosStorageInfo {
  final int freeDiskSize;
  final int totalDiskSize;
  final int physicalRamSize;
  final int availableRamSize;

  const IosStorageInfo({
    required this.freeDiskSize,
    required this.totalDiskSize,
    required this.physicalRamSize,
    required this.availableRamSize,
  });

  Map<String, dynamic> toJson() => {
    'freeDiskSize': freeDiskSize,
    'totalDiskSize': totalDiskSize,
    'physicalRamSize': physicalRamSize,
    'availableRamSize': availableRamSize,
  };
}

class IosUtsnameInfo {
  final String sysname;
  final String nodename;
  final String release;
  final String version;
  final String machine;

  const IosUtsnameInfo({
    required this.sysname,
    required this.nodename,
    required this.release,
    required this.version,
    required this.machine,
  });

  Map<String, dynamic> toJson() => {
    'sysname': sysname, 'nodename': nodename,
    'release': release, 'version': version,
    'machine': machine,
  };
}

// ── iOS 汇总 ──

class IosFingerprint {
  final IosDeviceInfo device;
  final IosStorageInfo storage;
  final IosUtsnameInfo utsname;

  const IosFingerprint({
    required this.device,
    required this.storage,
    required this.utsname,
  });

  Map<String, dynamic> toJson() => {
    'device': device.toJson(),
    'storage': storage.toJson(),
    'utsname': utsname.toJson(),
  };
}

// ── 顶层 ──

enum DevicePlatform { android, ios, unknown }

class DeviceFingerprint {
  final DevicePlatform platform;
  final AndroidFingerprint? android;
  final IosFingerprint? ios;

  const DeviceFingerprint._({
    required this.platform,
    this.android,
    this.ios,
  });

  factory DeviceFingerprint.android(AndroidFingerprint a) =>
      DeviceFingerprint._(platform: DevicePlatform.android, android: a);

  factory DeviceFingerprint.ios(IosFingerprint i) =>
      DeviceFingerprint._(platform: DevicePlatform.ios, ios: i);

  factory DeviceFingerprint.unknown() =>
      const DeviceFingerprint._(platform: DevicePlatform.unknown);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'platform': platform.name};
    if (android != null) {
      json['android'] = android!.toJson();
    }
    if (ios != null) {
      json['ios'] = ios!.toJson();
    }
    return json;
  }
}
