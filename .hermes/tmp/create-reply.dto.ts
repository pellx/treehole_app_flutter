import { IsString, IsNotEmpty, IsOptional, MaxLength, IsInt } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateReplyDto {
    @IsNotEmpty()
    postId: number;

    @IsNotEmpty()
    @IsString()
    @MaxLength(511)
    content: string;

    @IsOptional()
    @IsString()
    @MaxLength(100)
    author?: string;

    @IsInt()
    @Type(() => Number)
    session_id: number;

    @IsNotEmpty()
    @IsString()
    session_secret: string;
}
