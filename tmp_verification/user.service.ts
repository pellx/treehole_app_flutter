import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash, randomBytes } from 'crypto';
import * as bcrypt from 'bcrypt';
import { UserEntity } from './entities/user.entity';
import { DeviceEntity } from './entities/device.entity';
import { UserDeviceBindingEntity } from './entities/user-device-binding.entity';
import { SessionEntity } from './entities/session.entity';
import { UserIdentifierHistoryEntity } from './entities/user-identifier-history.entity';
import { RateLimitLogEntity } from './entities/rate-limit-log.entity';
import { VerificationService } from './verification/verification.service';
import { PoWStrategy } from './verification/pow.strategy';

const SESSION_TTL_MS = 3 * 24 * 60 * 60 * 1000;
const MAX_USER_DEVICES = 4;
const MAX_DEVICE_USERS = 3;
const RATE_LIMIT_COUNT = 5;
const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(DeviceEntity)
    private readonly deviceRepo: Repository<DeviceEntity>,
    @InjectRepository(UserDeviceBindingEntity)
    private readonly bindingRepo: Repository<UserDeviceBindingEntity>,
    @InjectRepository(SessionEntity)
    private readonly sessionRepo: Repository<SessionEntity>,
    @InjectRepository(UserIdentifierHistoryEntity)
    private readonly historyRepo: Repository<UserIdentifierHistoryEntity>,
    @InjectRepository(RateLimitLogEntity)
    private readonly rateLimitRepo: Repository<RateLimitLogEntity>,
    private readonly verificationService: VerificationService,
    private readonly powStrategy: PoWStrategy,
  ) {}

  async getPoWChallenge() {
    return this.powStrategy.createChallenge();
  }

  async initDevice(dto: {
    device_finger_print: any;
    verification_turnstile: string;
    verification_pow: string;
  }): Promise<{
    device_id: number;
    device_secret: string;
  }> {
    // Turnstile 验证
    const turnstileResult = await this.verificationService.verify('turnstile', dto.verification_turnstile);
    if (!turnstileResult.success) {
      throw new BadRequestException(turnstileResult.message ?? 'Turnstile 验证失败');
    }
    // PoW 验证
    const powResult = await this.verificationService.verify('pow', dto.verification_pow);
    if (!powResult.success) {
      throw new BadRequestException(powResult.message ?? 'PoW 验证失败');
    }

    const deviceSecret = this.generateDeviceSecret();
    const deviceSecretHash = await bcrypt.hash(deviceSecret, 10);

    const result = await this.deviceRepo.insert({
      device_secret_hash: deviceSecretHash,
      device_finger_print: dto.device_finger_print ?? null,
    });

    return {
      device_id: result.identifiers[0].device_id as number,
      device_secret: deviceSecret,
    };
  }

  async register(dto: {
    device_secret: string;
    device_finger_print?: any;
  }): Promise<{
    user_id: number;
    user_external_token: string;
    session_secret: string;
    session_id: number;
    device_id: number;
  }> {
    const device = await this.verifyDeviceSecret(dto.device_secret);

    const userExternalToken = this.generateExternalToken();

    const userResult = await this.userRepo.insert({
      user_external_token: userExternalToken,
    });
    const userId = userResult.identifiers[0].user_id as number;

    await this.bindUserToDevice(userId, device.device_id);

    const session = await this.issueSession(userId, device.device_id);

    return {
      user_id: userId,
      user_external_token: userExternalToken,
      session_secret: session.session_secret,
      session_id: session.session_id,
      device_id: device.device_id,
    };
  }

  async login(dto: {
    device_secret: string;
    device_finger_print?: any;
    user_external_token: string;
  }): Promise<{
    session_secret: string;
    session_id: number;
    device_id: number;
  }> {
    const device = await this.verifyDeviceSecret(dto.device_secret);

    const user = await this.userRepo.findOne({
      where: { user_external_token: dto.user_external_token },
    });
    if (!user) throw new BadRequestException('用户不存在');

    const existingBinding = await this.bindingRepo.findOne({
      where: { user_id: user.user_id, device_id: device.device_id, status: 'active' },
    });
    if (!existingBinding) {
      await this.bindUserToDevice(user.user_id, device.device_id);
    }

    const session = await this.issueSession(user.user_id, device.device_id);

    return {
      session_secret: session.session_secret,
      session_id: session.session_id,
      device_id: device.device_id,
    };
  }

  async validateSession(sessionId: number, sessionSecret: string): Promise<number> {
    const session = await this.sessionRepo.findOne({
      where: { session_id: sessionId },
    });
    if (!session) throw new UnauthorizedException('SESSION_INVALID');
    if (new Date() > session.expires_at)
      throw new UnauthorizedException('SESSION_EXPIRED');

    const hash = createHash('sha256').update(sessionSecret).digest('hex');
    if (hash !== session.session_secret_hash)
      throw new UnauthorizedException('SESSION_INVALID');

    return session.user_id;
  }

  async requestUnbind(userId: number, deviceId: number): Promise<void> {
    const binding = await this.bindingRepo.findOne({
      where: { user_id: userId, device_id: deviceId, status: 'active' },
    });
    if (!binding) throw new BadRequestException('绑定不存在');
    await this.bindingRepo.update(binding.id, {
      status: 'pending_unbind',
      unbind_requested_at: new Date(),
    });
  }

  async confirmUnbind(userId: number, deviceId: number): Promise<void> {
    const binding = await this.bindingRepo.findOne({
      where: { user_id: userId, device_id: deviceId, status: 'pending_unbind' },
    });
    if (!binding) throw new BadRequestException('无待解绑申请');

    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
    if (binding.unbind_requested_at! > threeDaysAgo) {
      throw new BadRequestException('解绑冷却期未满 3 天');
    }
    await this.bindingRepo.update(binding.id, {
      status: 'unbound',
      unbound_at: new Date(),
    });
  }

  // ============================================================
  // 子流程
  // ============================================================

  private async verifyDeviceSecret(
    deviceSecret: string,
  ): Promise<DeviceEntity> {
    const devices = await this.deviceRepo.find();
    for (const device of devices) {
      const match = await bcrypt.compare(
        deviceSecret,
        device.device_secret_hash,
      );
      if (match) return device;
    }
    throw new UnauthorizedException('DEVICE_SECRET_INVALID');
  }

  private async bindUserToDevice(
    userId: number,
    deviceId: number,
  ): Promise<void> {
    await this.authorizeNewBinding(userId, deviceId);

    await this.bindingRepo.manager.transaction(async (manager) => {
      const userCount = await manager.count(UserDeviceBindingEntity, {
        where: { user_id: userId, status: 'active' },
      });
      if (userCount >= MAX_USER_DEVICES)
        throw new BadRequestException('用户绑定设备数已达上限');

      const deviceCount = await manager.count(UserDeviceBindingEntity, {
        where: { device_id: deviceId, status: 'active' },
      });
      if (deviceCount >= MAX_DEVICE_USERS)
        throw new BadRequestException('设备绑定用户数已达上限');

      await manager.insert(UserDeviceBindingEntity, {
        user_id: userId,
        device_id: deviceId,
        status: 'active',
      });
    });
  }

  private async authorizeNewBinding(
    userId: number,
    deviceId: number,
  ): Promise<void> {
    return;
  }

  private async issueSession(
    userId: number,
    deviceId: number,
  ): Promise<{ session_id: number; session_secret: string }> {
    await this.checkRateLimit('user', String(userId));
    await this.checkRateLimit('device', String(deviceId));

    const sessionSecret = this.generateSessionSecret();
    const sessionSecretHash = createHash('sha256')
      .update(sessionSecret)
      .digest('hex');

    const result = await this.sessionRepo.insert({
      session_secret_hash: sessionSecretHash,
      user_id: userId,
      device_id: deviceId,
      expires_at: new Date(Date.now() + SESSION_TTL_MS),
    });

    await this.rateLimitRepo.insert([
      {
        subject_type: 'user',
        subject_id: String(userId),
        action: 'session_application',
      },
      {
        subject_type: 'device',
        subject_id: String(deviceId),
        action: 'session_application',
      },
    ]);

    return {
      session_id: result.identifiers[0].session_id as number,
      session_secret: sessionSecret,
    };
  }

  private async checkRateLimit(
    subjectType: string,
    subjectId: string,
  ): Promise<void> {
    const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS);
    const [result] = await this.rateLimitRepo.manager.query(
      `SELECT COUNT(*) as cnt FROM rate_limit_log
       WHERE subject_type = ? AND subject_id = ? AND action = 'session_application'
       AND created_at > ?`,
      [subjectType, subjectId, windowStart],
    );
    if (result?.cnt >= RATE_LIMIT_COUNT)
      throw new BadRequestException('RATE_LIMITED');
  }

  private generateExternalToken(): string {
    return randomBytes(32).toString('hex');
  }

  private generateDeviceSecret(): string {
    return randomBytes(32).toString('hex');
  }

  private generateSessionSecret(): string {
    return randomBytes(32).toString('hex');
  }
}
