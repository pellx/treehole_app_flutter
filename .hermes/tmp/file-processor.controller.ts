import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UploadedFile,
  UseInterceptors,
  UseGuards,
  Res,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { FileProcessorService } from './file-processor.service';
import { UploadFileDto } from './dto';
import { ClientTokenGuard } from '../common/guards/client-token.guard';

@Controller('file-processor')
export class FileProcessorController {
  constructor(private readonly fileProcessorService: FileProcessorService) {}

  @Post('upload')
  @UseGuards(ClientTokenGuard)
  @UseInterceptors(FileInterceptor('file'))
  async upload(
    @UploadedFile() file: Express.Multer.File,
    @Body() body: UploadFileDto,
  ) {
    return this.fileProcessorService.validate(file, body.type);
  }

  @Get('convert/:variant/*path')
  async convert(
    @Param('variant') variant: string,
    @Param('path') filenameParts: string | string[],
    @Res() res: Response,
  ) {
    const filename = Array.isArray(filenameParts)
      ? filenameParts.join('/')
      : filenameParts;
    const filePath = await this.fileProcessorService.convertImage(
      variant,
      filename,
    );
    res.sendFile(filePath);
  }
}
