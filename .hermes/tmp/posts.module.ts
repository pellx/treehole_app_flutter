import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PostsService } from './posts.service';
import { PostsController } from './posts.controller';

import { PostEntity } from './entities/post.entity';
import { ImageEntity } from './entities/image.entity';
import { AttachmentEntity } from './entities/attachment.entity';
import { CommentEntity } from './entities/comment.entity';
import { SearchModule } from '../search/search.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PostEntity,
      ImageEntity,
      AttachmentEntity,
      CommentEntity,
    ]),
    SearchModule,
    UserModule,
  ],
  controllers: [PostsController],
  providers: [PostsService],
})
export class PostsModule {}
