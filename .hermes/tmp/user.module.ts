import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserController } from './user.controller';
import { UserService } from './user.service';
import { UserEntity, DeviceEntity, FollowEntity, FollowAuthorEntity, UserSettingEntity } from '../migration/entities';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity, DeviceEntity, FollowEntity, FollowAuthorEntity, UserSettingEntity]),
  ],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
