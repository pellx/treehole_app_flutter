import { IsInt } from 'class-validator';
import { Type } from 'class-transformer';

export class UnbindDto {
  @IsInt()
  @Type(() => Number)
  user_id: number;

  @IsInt()
  @Type(() => Number)
  device_id: number;
}
