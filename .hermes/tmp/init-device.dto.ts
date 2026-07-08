import { IsOptional } from 'class-validator';

export class InitDeviceDto {
  @IsOptional()
  device_finger_print?: any;
}
