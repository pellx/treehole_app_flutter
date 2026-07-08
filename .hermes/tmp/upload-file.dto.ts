import { IsString, IsIn, IsOptional, IsNotEmpty, IsInt } from 'class-validator';
import { Type } from 'class-transformer';

export class UploadFileDto {
  @IsOptional()
  @IsString()
  @IsIn(['image', 'attachment'])
  type?: string;

  @IsInt()
  @Type(() => Number)
  session_id: number;

  @IsNotEmpty()
  @IsString()
  session_secret: string;
}
