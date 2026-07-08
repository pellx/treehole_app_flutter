import { Type } from 'class-transformer';
import {
  IsString, IsInt, IsBoolean, IsArray, IsOptional, ValidateNested,
} from 'class-validator';

// ── Android 子结构 ──

export class AndroidBuildInfo {
  @IsString() board: string;
  @IsString() bootloader: string;
  @IsString() brand: string;
  @IsString() device: string;
  @IsString() display: string;
  @IsString() fingerprint: string;
  @IsString() hardware: string;
  @IsString() host: string;
  @IsString() id: string;
  @IsString() manufacturer: string;
  @IsString() model: string;
  @IsString() product: string;
  @IsString() name: string;
  @IsString() tags: string;
  @IsString() type: string;
}

export class AndroidVersionInfo {
  @IsOptional() @IsString() baseOS?: string;
  @IsString() codename: string;
  @IsString() incremental: string;
  @IsOptional() @IsInt() previewSdkInt?: number;
  @IsString() release: string;
  @IsInt() sdkInt: number;
  @IsOptional() @IsString() securityPatch?: string;
}

export class AndroidAbiInfo {
  @IsArray() supported32BitAbis: string[];
  @IsArray() supported64BitAbis: string[];
  @IsArray() supportedAbis: string[];
}

export class AndroidHardwareInfo {
  @IsBoolean() isPhysicalDevice: boolean;
  @IsBoolean() isLowRamDevice: boolean;
  @IsInt() freeDiskSize: number;
  @IsInt() totalDiskSize: number;
  @IsInt() physicalRamSize: number;
  @IsInt() availableRamSize: number;
  @IsString() serialNumber: string;
  @IsArray() systemFeatures: string[];
}

// ── Android 汇总 ──

export class AndroidFingerprint {
  @ValidateNested() @Type(() => AndroidBuildInfo) build: AndroidBuildInfo;
  @ValidateNested() @Type(() => AndroidVersionInfo) version: AndroidVersionInfo;
  @ValidateNested() @Type(() => AndroidAbiInfo) abi: AndroidAbiInfo;
  @ValidateNested() @Type(() => AndroidHardwareInfo) hardware: AndroidHardwareInfo;
}

// ── iOS 子结构 ──

export class IosDeviceInfo {
  @IsString() name: string;
  @IsString() systemName: string;
  @IsString() systemVersion: string;
  @IsString() model: string;
  @IsString() modelName: string;
  @IsString() localizedModel: string;
  @IsOptional() @IsString() identifierForVendor?: string;
  @IsBoolean() isPhysicalDevice: boolean;
  @IsBoolean() isiOSAppOnMac: boolean;
}

export class IosStorageInfo {
  @IsInt() freeDiskSize: number;
  @IsInt() totalDiskSize: number;
  @IsInt() physicalRamSize: number;
  @IsInt() availableRamSize: number;
}

export class IosUtsnameInfo {
  @IsString() sysname: string;
  @IsString() nodename: string;
  @IsString() release: string;
  @IsString() version: string;
  @IsString() machine: string;
}

// ── iOS 汇总 ──

export class IosFingerprint {
  @ValidateNested() @Type(() => IosDeviceInfo) device: IosDeviceInfo;
  @ValidateNested() @Type(() => IosStorageInfo) storage: IosStorageInfo;
  @ValidateNested() @Type(() => IosUtsnameInfo) utsname: IosUtsnameInfo;
}

// ── 顶层 ──

export class DeviceFingerprintDto {
  @IsString() platform: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AndroidFingerprint)
  android?: AndroidFingerprint;

  @IsOptional()
  @ValidateNested()
  @Type(() => IosFingerprint)
  ios?: IosFingerprint;
}
