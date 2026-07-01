import { Controller, Post, Body } from '@nestjs/common';
import { IsString, IsNotEmpty, IsOptional, IsBoolean, IsArray } from 'class-validator';
import { UserService } from './user.service';

class RegisterDto {
  @IsString()
  @IsNotEmpty()
  client_token: string;

  @IsString()
  @IsNotEmpty()
  device_id: string;

  @IsString()
  @IsNotEmpty()
  platform: string;

  @IsString()
  @IsNotEmpty()
  device_model: string;

  @IsString()
  @IsNotEmpty()
  os_version: string;

  @IsOptional()
  @IsString()
  brand?: string;

  @IsOptional()
  @IsString()
  manufacturer?: string;

  @IsOptional()
  @IsBoolean()
  is_physical_device?: boolean;

  @IsOptional()
  @IsArray()
  supported_abis?: string[];
}

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.userService.register(dto);
  }
}
