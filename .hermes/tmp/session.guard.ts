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

    const sessionId = body?.session_id;
    const sessionSecret = body?.session_secret;

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
