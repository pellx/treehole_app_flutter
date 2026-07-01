import { IsString, IsIn, IsOptional, IsNotEmpty } from 'class-validator';

export class UploadFileDto {
  @IsOptional()
  @IsString()
  @IsIn(['image', 'attachment'])
  type?: string;

  @IsNotEmpty()
  @IsString()
  client_token: string;
}
