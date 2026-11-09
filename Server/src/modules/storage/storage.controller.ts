import { Controller, Get, Param, Res } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { Response } from 'express';
import { StorageService } from './storage.service';

@ApiTags('Storage & Media')
@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Get(':folder/:filename')
  @ApiOperation({
    summary: 'Stream media file securely from private S3 or local storage',
    description:
      'Serves avatars and item images securely from private AWS S3 bucket without requiring public bucket access.',
  })
  @ApiResponse({ status: 200, description: 'Image binary stream' })
  @ApiResponse({ status: 404, description: 'File not found' })
  async getFile(
    @Param('folder') folder: 'avatars' | 'items',
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    return this.storageService.streamFile(folder, filename, res);
  }
}

