import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { UserService } from '../../user/user.service';

@Injectable()
export class ClientTokenGuard implements CanActivate {
  constructor(private readonly userService: UserService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const body = request.body;

    const localTokenHash = body?.local_token_hash;
    const externalToken = body?.external_token;
    const deviceId = body?.device_id;

    if (!localTokenHash || !externalToken || !deviceId) {
      throw new UnauthorizedException('MISSING_AUTH_FIELDS');
    }

    const userToken = await this.userService.validate({
      local_token_hash: localTokenHash,
      external_token: externalToken,
      device_id: deviceId,
      platform: body?.platform ?? 'unknown',
      device_model: body?.device_model ?? 'unknown',
      os_version: body?.os_version ?? '0',
      brand: body?.brand,
      manufacturer: body?.manufacturer,
    });

    request.user_token = userToken;
    return true;
  }
}
