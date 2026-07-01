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
    const body = request.body || {};

    const clientToken = body.client_token;
    if (!clientToken) {
      throw new UnauthorizedException('Missing client_token');
    }

    const deviceId = body.device_id;
    const osVersion = body.os_version;

    const userToken = await this.userService.validate(
      clientToken,
      deviceId,
      osVersion,
    );

    request.user_token = userToken;
    return true;
  }
}
