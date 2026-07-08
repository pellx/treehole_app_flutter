import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  device_secret: string;

  @IsOptional()
  device_finger_print?: any;
}
