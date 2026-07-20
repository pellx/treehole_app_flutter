import { IsInt, IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';

/** 修改用户-设备绑定上的自定义设备名 */
export class RenameDeviceDto {
  @IsInt()
  @Type(() => Number)
  device_id: number;

  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  new_name: string;

  @IsInt()
  @Type(() => Number)
  session_id: number;

  @IsNotEmpty()
  @IsString()
  session_secret: string;
}
