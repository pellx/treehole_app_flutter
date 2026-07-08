import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEntity } from './entities/user.entity';
import { DeviceEntity } from '../device/entities/device.entity';
import { UserDeviceBindingEntity } from '../device/entities/user-device-binding.entity';
import { SessionEntity } from '../device/entities/session.entity';
import { UserIdentifierHistoryEntity } from '../device/entities/user-identifier-history.entity';
import { RateLimitLogEntity } from '../device/entities/rate-limit-log.entity';
import { UserService } from './user.service';
import { UserController } from './user.controller';
import { SessionGuard } from '../common/guards/session.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      DeviceEntity,
      UserDeviceBindingEntity,
      SessionEntity,
      UserIdentifierHistoryEntity,
      RateLimitLogEntity,
    ]),
  ],
  controllers: [UserController],
  providers: [UserService, SessionGuard],
  exports: [UserService, SessionGuard, TypeOrmModule],
})
export class UserModule {}
