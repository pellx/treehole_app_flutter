import { IsString, IsNotEmpty, IsOptional, IsArray, ValidateNested, MaxLength, ArrayMaxSize, IsIn } from 'class-validator';
import { Type } from 'class-transformer';

export class UploadItemDto {
    @IsString()
    @IsIn(['image', 'attachment'])
    type: string;

    @IsString()
    @IsOptional()
    original?: string;

    @IsString()
    @IsNotEmpty()
    filename: string;
}

export class CreatePostDto {
    @IsNotEmpty()
    @IsString()
    @MaxLength(255)
    title: string;

    @IsOptional()
    @IsString()
    content?: string;

    @IsOptional()
    @IsString()
    @MaxLength(100)
    author?: string;

    @IsOptional()
    @IsArray()
    @ArrayMaxSize(13)
    @ValidateNested({ each: true })
    @Type(() => UploadItemDto)
    uploaded: UploadItemDto[] = [];

    @IsNotEmpty()
    @IsString()
    client_token: string;
}
