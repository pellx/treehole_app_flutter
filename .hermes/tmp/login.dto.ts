import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  device_secret: string;

  @IsOptional()
  device_finger_print?: any;

  @IsString()
  @IsNotEmpty()
  user_external_token: string;
}
