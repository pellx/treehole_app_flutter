import { IsString, IsNotEmpty, IsOptional, MaxLength } from 'class-validator';

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

    @IsNotEmpty()
    @IsString()
    client_token: string;
}
