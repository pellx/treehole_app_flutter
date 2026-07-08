import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import {
  createChallenge,
  verifySolution,
} from 'altcha-lib/v1';
import { VerificationStrategy, VerificationResult } from './verification-strategy.interface';

// ALTCHA v1 challenge options
const CHALLENGE_MAX = 100_000; // 10万次 hash，手机 ~100-500ms
const CHALLENGE_EXPIRES_MS = 5 * 60 * 1000; // 5 分钟过期

@Injectable()
export class PoWStrategy implements VerificationStrategy {
  readonly method = 'pow';
  private readonly logger = new Logger(PoWStrategy.name);
  private readonly hmacKey: string;
  private readonly enabled: boolean;

  constructor() {
    this.hmacKey = process.env.POW_HMAC_KEY ?? '';
    this.enabled = this.hmacKey.length > 0;
    if (!this.enabled) {
      this.logger.warn('POW_HMAC_KEY not set — PoW verification disabled');
    }
  }

  async createChallenge() {
    if (!this.enabled) {
      throw new BadRequestException('PoW 服务未配置');
    }
    return createChallenge({
      hmacKey: this.hmacKey,
      maxnumber: CHALLENGE_MAX,
      algorithm: 'SHA-256',
      expires: new Date(Date.now() + CHALLENGE_EXPIRES_MS),
    });
  }

  async verify(token: string): Promise<VerificationResult> {
    if (!this.enabled) {
      return { success: false, message: '服务端未配置 PoW' };
    }

    try {
      const payload = typeof token === 'string' ? JSON.parse(token) : token;
      const valid = await verifySolution(payload, this.hmacKey);
      return valid
        ? { success: true }
        : { success: false, message: 'PoW 验证失败' };
    } catch (err) {
      this.logger.warn(`PoW verify error: ${err}`);
      return { success: false, message: 'PoW 验证格式错误' };
    }
  }
}
