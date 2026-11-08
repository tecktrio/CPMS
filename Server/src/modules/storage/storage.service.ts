import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  constructor(private readonly configService: ConfigService) {}

  async uploadFile(
    file: Express.Multer.File,
    folder: 'avatars' | 'items' = 'items',
  ): Promise<string> {
    if (!file) {
      throw new BadRequestException('No image file provided');
    }

    // Validate that uploaded file is an image
    const allowedMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'image/heic',
      'image/heif',
    ];
    if (!allowedMimeTypes.includes(file.mimetype.toLowerCase())) {
      throw new BadRequestException(
        `Invalid file type '${file.mimetype}'. Only JPEG, PNG, WEBP, GIF, and HEIC images are allowed.`,
      );
    }

    const s3Config = this.configService.get('aws');
    const bucket = s3Config?.s3Bucket;
    const region = s3Config?.region || 'us-east-1';
    const accessKeyId = s3Config?.accessKeyId;
    const secretAccessKey = s3Config?.secretAccessKey;

    const originalExt = path.extname(file.originalname) || '.jpg';
    const filename = `${uuidv4()}${originalExt}`;
    const s3Key = `${folder}/${filename}`;

    // Upload to AWS S3 if credentials are fully configured
    if (bucket && accessKeyId && secretAccessKey) {
      try {
        const s3Client = new S3Client({
          region,
          credentials: {
            accessKeyId,
            secretAccessKey,
          },
          endpoint: s3Config.endpoint || undefined,
          forcePathStyle: Boolean(s3Config.endpoint),
        });

        await s3Client.send(
          new PutObjectCommand({
            Bucket: bucket,
            Key: s3Key,
            Body: file.buffer,
            ContentType: file.mimetype,
          }),
        );

        const publicUrl = s3Config.publicUrlPrefix
          ? `${s3Config.publicUrlPrefix.replace(/\/$/, '')}/${s3Key}`
          : `https://${bucket}.s3.${region}.amazonaws.com/${s3Key}`;

        this.logger.log(`Successfully uploaded ${s3Key} to AWS S3 (${publicUrl})`);
        return publicUrl;
      } catch (error) {
        this.logger.error(
          `AWS S3 upload failed: ${(error as Error).message}. Falling back to local storage.`,
        );
      }
    } else {
      this.logger.log(
        'AWS S3 credentials not configured in environment. Using local static file storage fallback.',
      );
    }

    // Fallback: Local file storage in ./uploads/{folder}
    const uploadsDir = path.join(process.cwd(), 'uploads', folder);
    await fs.promises.mkdir(uploadsDir, { recursive: true });
    const localFilePath = path.join(uploadsDir, filename);
    await fs.promises.writeFile(localFilePath, file.buffer);

    const localUrl = `/uploads/${folder}/${filename}`;
    this.logger.log(`Saved image locally to ${localUrl}`);
    return localUrl;
  }
}

