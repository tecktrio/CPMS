import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { v4 as uuidv4 } from 'uuid';
import { Response } from 'express';
import { Readable } from 'stream';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  constructor(private readonly configService: ConfigService) {}

  extractS3Key(fileUrlOrKey?: string | null): string | null {
    if (!fileUrlOrKey || typeof fileUrlOrKey !== 'string') return null;
    const clean = fileUrlOrKey.trim();
    // Matches e.g. "avatars/uuid.png" or "items/uuid.jpg"
    const match = clean.match(/(avatars|items)\/[a-zA-Z0-9_\-\.]+/i);
    return match ? match[0] : null;
  }

  async deleteFile(fileUrlOrKey?: string | null): Promise<void> {
    if (!fileUrlOrKey) return;
    const s3Key = this.extractS3Key(fileUrlOrKey);
    if (!s3Key) {
      this.logger.warn(`Could not extract storage key from: ${fileUrlOrKey}`);
      return;
    }

    // 1. Delete from AWS S3 if configured
    const s3Config = this.configService.get('aws');
    const bucket = s3Config?.s3Bucket;
    const region = s3Config?.region || 'us-east-1';
    const accessKeyId = s3Config?.accessKeyId;
    const secretAccessKey = s3Config?.secretAccessKey;

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
          new DeleteObjectCommand({
            Bucket: bucket,
            Key: s3Key,
          }),
        );
        this.logger.log(`Deleted replaced object from AWS S3: ${s3Key}`);
      } catch (err) {
        this.logger.warn(
          `Failed to delete old object ${s3Key} from AWS S3: ${(err as Error).message}`,
        );
      }
    }

    // 2. Delete from local disk if it exists
    try {
      const localFilePath = path.join(process.cwd(), 'uploads', s3Key);
      if (fs.existsSync(localFilePath)) {
        await fs.promises.unlink(localFilePath);
        this.logger.log(`Deleted local file: ${localFilePath}`);
      }
    } catch (err) {
      this.logger.warn(
        `Failed to delete local file for ${s3Key}: ${(err as Error).message}`,
      );
    }
  }

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

    const originalExt = (path.extname(file.originalname || '') || '').toLowerCase();
    const extToMime: Record<string, string> = {
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.webp': 'image/webp',
      '.gif': 'image/gif',
      '.heic': 'image/heic',
      '.heif': 'image/heif',
    };

    let effectiveMimeType = (file.mimetype || '').toLowerCase();
    if (
      effectiveMimeType === 'application/octet-stream' ||
      !allowedMimeTypes.includes(effectiveMimeType)
    ) {
      if (extToMime[originalExt]) {
        effectiveMimeType = extToMime[originalExt];
      }
    }

    if (!allowedMimeTypes.includes(effectiveMimeType)) {
      throw new BadRequestException(
        `Invalid file type '${file.mimetype}'. Only JPEG, PNG, WEBP, GIF, and HEIC images are allowed.`,
      );
    }

    const s3Config = this.configService.get('aws');
    const bucket = s3Config?.s3Bucket;
    const region = s3Config?.region || 'us-east-1';
    const accessKeyId = s3Config?.accessKeyId;
    const secretAccessKey = s3Config?.secretAccessKey;

    const fileExt = originalExt || (effectiveMimeType === 'image/png' ? '.png' : '.jpg');
    const filename = `${uuidv4()}${fileExt}`;
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
            ContentType: effectiveMimeType,
          }),
        );

        const storageProxyUrl = `/api/v1/storage/${s3Key}`;
        const returnedUrl = s3Config.publicUrlPrefix
          ? `${s3Config.publicUrlPrefix.replace(/\/$/, '')}/${s3Key}`
          : storageProxyUrl;

        this.logger.log(`Successfully uploaded ${s3Key} to AWS S3 (Serving via ${returnedUrl})`);
        return returnedUrl;
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

    const localUrl = `/api/v1/storage/${folder}/${filename}`;
    this.logger.log(`Saved image locally to ${localUrl}`);
    return localUrl;
  }

  async streamFile(
    folder: 'avatars' | 'items',
    filename: string,
    res: Response,
  ): Promise<void> {
    const s3Key = `${folder}/${filename}`;
    const ext = (path.extname(filename) || '').toLowerCase();
    const extToMime: Record<string, string> = {
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.webp': 'image/webp',
      '.gif': 'image/gif',
      '.heic': 'image/heic',
      '.heif': 'image/heif',
    };
    const mimeType = extToMime[ext] || 'application/octet-stream';

    const s3Config = this.configService.get('aws');
    const bucket = s3Config?.s3Bucket;
    const region = s3Config?.region || 'us-east-1';
    const accessKeyId = s3Config?.accessKeyId;
    const secretAccessKey = s3Config?.secretAccessKey;

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

        const command = new GetObjectCommand({
          Bucket: bucket,
          Key: s3Key,
        });

        const s3Response = await s3Client.send(command);
        res.setHeader('Content-Type', s3Response.ContentType || mimeType);
        res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
        if (s3Response.ContentLength) {
          res.setHeader('Content-Length', s3Response.ContentLength);
        }

        const stream = s3Response.Body as Readable;
        stream.pipe(res);
        return;
      } catch (err) {
        this.logger.warn(
          `S3 fetch for ${s3Key} failed: ${(err as Error).message}. Checking local disk.`,
        );
      }
    }

    const localFilePath = path.join(process.cwd(), 'uploads', folder, filename);
    if (fs.existsSync(localFilePath)) {
      res.setHeader('Content-Type', mimeType);
      res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
      const stream = fs.createReadStream(localFilePath);
      stream.pipe(res);
      return;
    }

    res.status(404).json({
      statusCode: 404,
      message: `File ${folder}/${filename} not found`,
    });
  }
}

