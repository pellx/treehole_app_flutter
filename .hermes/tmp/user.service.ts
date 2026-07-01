import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash } from 'crypto';
import { UserEntity } from '../user/entities';
import { DeviceEntity } from '../device/entities';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(DeviceEntity)
    private readonly deviceRepo: Repository<DeviceEntity>,
  ) {}

  /**
   * 注册新设备。如果 device_id 已注册 → 拒绝。
   * 如果 local_token_hash 已在其他设备 → 绑到同一个 user。
   */
  async register(dto: {
    client_token: string;
    device_id: string;
    platform: string;
    device_model: string;
    os_version: string;
    brand?: string;
    manufacturer?: string;
    is_physical_device?: boolean;
    supported_abis?: string[];
  }): Promise<{ internal_token: string }> {
    const localTokenHash = this.hashToken(dto.client_token);

    // 该设备是否已注册
    const existingDevice = await this.deviceRepo.findOne({
      where: { device_id: dto.device_id },
      relations: ['user'],
    });
    if (existingDevice) {
      throw new UnauthorizedException('Device already registered');
    }

    // local_token_hash 是否绑定到已有用户（设备迁移场景）
    const siblingDevice = await this.deviceRepo.findOne({
      where: { local_token_hash: localTokenHash },
      relations: ['user'],
    });

    let internalToken: string;

    if (siblingDevice) {
      // 绑定到已有用户
      internalToken = siblingDevice.user_token;
    } else {
      // 新建用户
      internalToken = createHash('sha256')
        .update(`${dto.device_id}:${Date.now()}:${Math.random()}`)
        .digest('hex')
        .substring(0, 64);

      await this.userRepo.insert({
        internal_token: internalToken,
      });
    }

    // 创建设备记录
    await this.deviceRepo.insert({
      user_token: internalToken,
      device_id: dto.device_id,
      platform: dto.platform,
      device_model: dto.device_model,
      os_version: dto.os_version,
      brand: dto.brand ?? null,
      manufacturer: dto.manufacturer ?? null,
      is_physical_device: dto.is_physical_device ?? true,
      supported_abis: dto.supported_abis ?? null,
      local_token_hash: localTokenHash,
    });

    return { internal_token: internalToken };
  }

  /**
   * 验证 client_token，返回 user_token。
   * 同时校验 os_version 只升不降。
   */
  async validate(
    clientToken: string,
    deviceId?: string,
    osVersion?: string,
  ): Promise<string> {
    const localTokenHash = this.hashToken(clientToken);
    const device = await this.deviceRepo.findOne({
      where: { local_token_hash: localTokenHash },
      relations: ['user'],
    });

    if (!device) {
      throw new UnauthorizedException('Invalid client token');
    }

    // 校验 device_id 匹配（如果提供了）
    if (deviceId && device.device_id !== deviceId) {
      throw new UnauthorizedException('Device mismatch');
    }

    // 校验 os_version 只升不降
    if (osVersion && device.os_version) {
      const [oldMajor, oldMinor] = device.os_version.split('.').map(Number);
      const [newMajor, newMinor] = osVersion.split('.').map(Number);
      if (
        newMajor < oldMajor ||
        (newMajor === oldMajor && newMinor < oldMinor)
      ) {
        throw new UnauthorizedException('OS version downgrade detected');
      }
      // 更新 os_version
      if (newMajor > oldMajor || (newMajor === oldMajor && newMinor > oldMinor)) {
        await this.deviceRepo.update(device.id, { os_version: osVersion });
      }
    }

    return device.user_token;
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
