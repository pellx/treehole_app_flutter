import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { UserLoginService } from '../../user/user.service.login';

@Injectable()
export class SessionGuard implements CanActivate {
  constructor(private readonly userLoginService: UserLoginService) { }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const body = request.body;

    const sessionId =
      body?.session_id ??
      request.headers['x-session-id'];
    const sessionSecret =
      body?.session_secret ??
      request.headers['x-session-secret'];

    if (!sessionId || !sessionSecret) {
      throw new UnauthorizedException('MISSING_SESSION');
    }

    const session = await this.userLoginService.validateSession(
      sessionId,
      sessionSecret,
    );

    request.user_id = session.user_id;
    request.device_id = session.device_id;
    return true;
  }
}
