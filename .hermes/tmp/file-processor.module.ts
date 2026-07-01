import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { FileProcessorController } from './file-processor.controller';
import { FileProcessorService } from './file-processor.service';
import { UserModule } from '../user/user.module';

@Module({
  imports: [
    MulterModule.registerAsync({
      useClass: FileProcessorService,
    }),
    UserModule,
  ],
  controllers: [FileProcessorController],
  providers: [FileProcessorService],
  exports: [FileProcessorService],
})
export class FileProcessorModule {}
