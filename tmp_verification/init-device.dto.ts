import { IsString, IsNotEmpty, IsOptional, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { DeviceFingerprintDto } from './fingerprint.dto';

export class InitDeviceDto {
  @ValidateNested()
  @Type(() => DeviceFingerprintDto)
  device_finger_print: DeviceFingerprintDto;

  @IsString()
  @IsNotEmpty()
  verification_turnstile: string;

  @IsString()
  @IsNotEmpty()
  verification_pow: string;
}
