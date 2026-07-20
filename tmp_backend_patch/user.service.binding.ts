import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, In, Repository } from 'typeorm';
import { UserDeviceBindingEntity } from './entities/user-device-binding.entity';
import { DeviceEntity } from './entities/device.entity';
import { FingerprintEntity } from './entities/fingerprint.entity';
import { UserEntity } from './entities/user.entity';

const MAX_USER_DEVICES = 5;
const MAX_DEVICE_USERS = 3;

@Injectable()
export class UserBindingService {
  constructor(
    @InjectRepository(UserDeviceBindingEntity)
    private readonly bindingRepo: Repository<UserDeviceBindingEntity>,
    @InjectRepository(DeviceEntity)
    private readonly deviceRepo: Repository<DeviceEntity>,
    @InjectRepository(FingerprintEntity)
    private readonly fingerprintRepo: Repository<FingerprintEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
  ) { }

  async bindUserToDevice(
    manager: EntityManager,
    userId: number,
    deviceId: number,
  ): Promise<void> {
    await this.authorizeNewBinding(userId, deviceId);

    const userCount = await manager.count(UserDeviceBindingEntity, {
      where: { user_id: userId, status: 'active' },
    });
    if (userCount >= MAX_USER_DEVICES) {
      throw new BadRequestException('用户绑定设备数已达上限');
    }

    const deviceCount = await manager.count(UserDeviceBindingEntity, {
      where: { device_id: deviceId, status: 'active' },
    });
    if (deviceCount >= MAX_DEVICE_USERS) {
      throw new BadRequestException('设备绑定用户数已达上限');
    }

    await manager.insert(UserDeviceBindingEntity, {
      user_id: userId,
      device_id: deviceId,
      status: 'active',
    });
  }

  /**
   * 当前账户绑定的所有设备（devices2user）
   */
  async listDevicesForUser(userId: number): Promise<{
    devices: Array<{
      id: number;
      device_id: number;
      device_display_name: string | null;
      device_name: string | null;
      fingerprint: string | null;
      brand: string | null;
      model: string | null;
      os: string | null;
      memory: string | null;
    }>;
  }> {
    const bindings = await this.bindingRepo.find({
      where: { user_id: userId, status: 'active' },
    });
    if (bindings.length === 0) {
      return { devices: [] };
    }

    const deviceIds = bindings.map((b) => b.device_id);
    const devices = await this.deviceRepo.find({
      where: { device_id: In(deviceIds) },
    });
    const fps = await this.fingerprintRepo.find({
      where: { device_id: In(deviceIds) },
    });
    const deviceById = new Map(devices.map((d) => [d.device_id, d]));
    const fpByDevice = new Map(fps.map((f) => [f.device_id, f]));
    const bindingByDevice = new Map(bindings.map((b) => [b.device_id, b]));

    return {
      devices: deviceIds.flatMap((id) => {
        const b = bindingByDevice.get(id);
        if (!b) return [];
        const d = deviceById.get(id);
        const fp = fpByDevice.get(id);
        const meta = this.summarizeFingerprint(fp);
        return [
          {
            id: b.id,
            device_id: id,
            device_display_name: b.device_display_name ?? null,
            device_name: d?.device_name ?? meta.model ?? null,
            fingerprint: fp?.fingerprint_hash ?? d?.fingerprint_hash ?? null,
            brand: meta.brand,
            model: meta.model,
            os: meta.os,
            memory: meta.memory,
          },
        ];
      }),
    };
  }

  /** 从指纹拼出卡片展示用字段 */
  private summarizeFingerprint(fp: FingerprintEntity | undefined): {
    brand: string | null;
    model: string | null;
    os: string | null;
    memory: string | null;
  } {
    if (!fp) {
      return { brand: null, model: null, os: null, memory: null };
    }

    const platform = (fp.platform ?? '').toLowerCase();
    if (platform === 'ios') {
      const anyFp = fp as FingerprintEntity & {
        ios_model?: string | null;
        ios_model_name?: string | null;
        ios_system_name?: string | null;
        ios_system_version?: string | null;
        ios_physical_ram_size?: number | null;
      };
      const brand = 'Apple';
      const model = anyFp.ios_model_name ?? anyFp.ios_model ?? null;
      const sys = anyFp.ios_system_name ?? 'iOS';
      const ver = anyFp.ios_system_version;
      const os = ver ? `${sys} ${ver}` : sys;
      return {
        brand,
        model,
        os,
        memory: this.formatRam(anyFp.ios_physical_ram_size),
      };
    }

    const brand = fp.build_brand ?? fp.build_manufacturer ?? null;
    const model = fp.build_model ?? null;
    const release = (fp as FingerprintEntity & { version_release?: string | null })
      .version_release;
    const os = release ? `Android ${release}` : 'Android';
    const ram = (fp as FingerprintEntity & { hw_physical_ram_size?: number | null })
      .hw_physical_ram_size;
    return {
      brand,
      model,
      os,
      memory: this.formatRam(ram),
    };
  }

  private formatRam(bytes: number | null | undefined): string | null {
    if (bytes == null || !Number.isFinite(bytes) || bytes <= 0) return null;
    const gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) {
      const rounded = Math.round(gb * 10) / 10;
      return `${Number.isInteger(rounded) ? rounded.toFixed(0) : rounded} GB`;
    }
    const mb = Math.round(bytes / (1024 * 1024));
    return `${mb} MB`;
  }

  /**
   * 当前设备绑定的所有账户（user2device）
   */
  async listUsersForDevice(deviceId: number): Promise<{
    users: Array<{
      id: number;
      device_id: number;
      user_token: string;
      user_display_id: string | null;
    }>;
  }> {
    const bindings = await this.bindingRepo.find({
      where: { device_id: deviceId, status: 'active' },
    });
    if (bindings.length === 0) {
      return { users: [] };
    }

    const userIds = bindings.map((b) => b.user_id);
    const users = await this.userRepo.find({
      where: { user_id: In(userIds) },
    });
    const userById = new Map(users.map((u) => [u.user_id, u]));

    return {
      users: bindings.flatMap((b) => {
        const u = userById.get(b.user_id);
        if (!u) return [];
        return [
          {
            id: b.id,
            device_id: b.device_id,
            user_token: u.user_token,
            user_display_id: u.user_display_id ?? null,
          },
        ];
      }),
    };
  }

  /**
   * 修改当前用户对某设备的绑定显示名（写入 user_device_binding）
   */
  async renameDevice(
    userId: number,
    deviceId: number,
    newName: string,
  ): Promise<{ device_id: number; device_display_name: string }> {
    const name = newName.trim();
    if (!name) throw new BadRequestException('NAME_EMPTY');
    if (name.length > 100) throw new BadRequestException('NAME_TOO_LONG');

    const binding = await this.bindingRepo.findOne({
      where: { user_id: userId, device_id: deviceId, status: 'active' },
    });
    if (!binding) {
      throw new UnauthorizedException('DEVICE_NOT_BOUND');
    }

    if (binding.device_display_name === name) {
      throw new BadRequestException('NAME_UNCHANGED');
    }

    await this.bindingRepo.update(
      { id: binding.id },
      { device_display_name: name },
    );

    return { device_id: deviceId, device_display_name: name };
  }

  private async authorizeNewBinding(_userId: number, _deviceId: number): Promise<void> {
    return;
  }
}
