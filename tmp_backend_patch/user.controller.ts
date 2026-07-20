import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, UnauthorizedException, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { CheckLoginDto } from './dto/check.dto';
import { RegisterDto } from './dto/register.dto';
import { RenameDto } from './dto/rename.dto';
import { RenameDeviceDto } from './dto/rename-device.dto';
import { SessionCreateDto } from './dto/session-create.dto';
import { SessionOnlyDto } from './dto/session-only.dto';
import { SessionValidateDto } from './dto/session-validate.dto';
import { SessionGuard } from '../common/guards/session.guard';
import { UserLoginService } from './user.service.login';
import { UserProfileService } from './user.service.profile';
import { UserBindingService } from './user.service.binding';
import { UserService } from './user.service';

@Controller('user')
export class UserController {
  constructor(
    private readonly userService: UserService,
    private readonly userLoginService: UserLoginService,
    private readonly userProfileService: UserProfileService,
    private readonly userBindingService: UserBindingService,
  ) { }

  @Get('pow-challenge')
  async getPoWChallenge() {
    return this.userService.getPoWChallenge();
  }

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.userLoginService.register(dto, req.ip);
  }

  @Post('check')
  @HttpCode(HttpStatus.OK)
  async check(@Body() dto: CheckLoginDto) {
    return this.userLoginService.checkLogin(dto);
  }

  @Post('session/create')
  @HttpCode(HttpStatus.CREATED)
  async createSession(@Body() dto: SessionCreateDto) {
    return this.userLoginService.createSession(dto);
  }

  @Post('session/validate')
  @HttpCode(HttpStatus.OK)
  async validateSessionEndpoint(@Body() dto: SessionValidateDto) {
    return this.userLoginService.validateSessionEndpoint(dto);
  }

  @Post('profile')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  async getProfile(@Body() _dto: SessionOnlyDto, @Req() req: Request & { user_id: number }) {
    return this.userProfileService.getProfile(req.user_id);
  }

  @Post('rename')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  async rename(@Body() dto: RenameDto, @Req() req: Request & { user_id: number }) {
    return this.userProfileService.rename(req.user_id, dto.new_name);
  }

  @Post('token/reset')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  async resetToken(@Body() _dto: SessionOnlyDto, @Req() req: Request & { user_id: number }) {
    return this.userProfileService.resetToken(req.user_id);
  }

  /** 当前账户绑定的所有设备 */
  @Post('devices2user')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  async devices2user(
    @Body() _dto: SessionOnlyDto,
    @Req() req: Request & { user_id: number },
  ) {
    return this.userBindingService.listDevicesForUser(req.user_id);
  }

  /** 当前设备绑定的所有账户 */
  @Post('user2device')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  async user2device(
    @Body() _dto: SessionOnlyDto,
    @Req() req: Request & { device_id: number },
  ) {
    if (req.device_id == null) {
      throw new UnauthorizedException('SESSION_INVALID');
    }
    return this.userBindingService.listUsersForDevice(req.device_id);
  }

  /** 修改当前用户对某设备的自定义显示名（写入绑定表） */
  @Post('device/rename')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  async renameDevice(
    @Body() dto: RenameDeviceDto,
    @Req() req: Request & { user_id: number },
  ) {
    return this.userBindingService.renameDevice(
      req.user_id,
      dto.device_id,
      dto.new_name,
    );
  }
}
