import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MigrationController } from './migration.controller';
import { MigrationService } from './migration.service';
import { UserEntity, DeviceEntity, FollowEntity, FollowAuthorEntity, UserSettingEntity } from './entities';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity, DeviceEntity, FollowEntity, FollowAuthorEntity, UserSettingEntity]),
  ],
  controllers: [MigrationController],
  providers: [MigrationService],
  exports: [MigrationService],
})
export class MigrationModule {}
