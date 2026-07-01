import {
  Controller,
  Get,
  Post,
  Query,
  Param,
  Body,
  HttpCode,
  HttpStatus,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { PostsService } from './posts.service';
import { GetPostDto } from './dto/get-post.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { CreateReplyDto } from './dto/create-reply.dto';
import { ClientTokenGuard } from '../common/guards/client-token.guard';

@Controller('posts')
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Post()
  @UseGuards(ClientTokenGuard)
  createPost(@Body() createPostDto: CreatePostDto) {
    return this.postsService.createPost(createPostDto);
  }

  @Post('comment')
  @UseGuards(ClientTokenGuard)
  createReply(@Body() createReplyDto: CreateReplyDto) {
    return this.postsService.createReply(createReplyDto);
  }

  @Post('idListUpdate')
  getIdListUpdate(@Body() ids: number[]) {
    return this.postsService.findUpdate(ids);
  }

  @Get('idList')
  getIdList(@Query() query: GetPostDto) {
    return this.postsService.findList(query);
  }

  @Get('idListByAuthor/:author')
  getIdListByAuthor(@Param('author') str: string) {
    return this.postsService.findListByAuthor(str);
  }

  @Get('comment/:id')
  getComment(@Param('id', ParseIntPipe) id: number) {
    return this.postsService.findComment(id);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.postsService.findOne(id);
  }
}
