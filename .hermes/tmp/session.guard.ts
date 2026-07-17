import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { UserService } from '../../user/user.service';

@Injectable()
export class SessionGuard implements CanActivate {
  constructor(private readonly userService: UserService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const body = request.body;

    // JSON body 走 fields；multipart upload 在 Guard 阶段 body 尚未解析，须读 header
    const sessionId =
      body?.session_id ??
      request.headers['x-session-id'];
    const sessionSecret =
      body?.session_secret ??
      request.headers['x-session-secret'];

    if (!sessionId || !sessionSecret) {
      throw new UnauthorizedException('MISSING_SESSION');
    }

    const userId = await this.userService.validateSession(
      sessionId,
      sessionSecret,
    );

    request.user_id = userId;
    return true;
  }
}
