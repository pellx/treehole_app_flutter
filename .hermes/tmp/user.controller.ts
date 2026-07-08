import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { UserService } from './user.service';
import { InitDeviceDto, RegisterDto, LoginDto, UnbindDto } from './dto';

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('init-device')
  @HttpCode(HttpStatus.CREATED)
  async initDevice(@Body() dto: InitDeviceDto) {
    return this.userService.initDevice(dto);
  }

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() dto: RegisterDto) {
    return this.userService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto) {
    return this.userService.login(dto);
  }

  @Post('request-unbind')
  async requestUnbind(@Body() dto: UnbindDto) {
    await this.userService.requestUnbind(dto.user_id, dto.device_id);
    return { status: 'pending' };
  }

  @Post('confirm-unbind')
  async confirmUnbind(@Body() dto: UnbindDto) {
    await this.userService.confirmUnbind(dto.user_id, dto.device_id);
    return { status: 'unbound' };
  }
}
