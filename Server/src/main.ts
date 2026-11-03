import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformResponseInterceptor } from './common/interceptors/transform-response.interceptor';

async function bootstrap() {
  const logger = new Logger('CIMS-Bootstrap');
  const app = await NestFactory.create(AppModule);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port', 3000);

  // Enable CORS for mobile application clients
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-ID'],
  });

  // Global prefix for all API routes
  app.setGlobalPrefix('api/v1');

  // Global validation pipe for all DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // Global exception filter for unified error structure
  app.useGlobalFilters(new HttpExceptionFilter());

  // Global response interceptor for unified success structure
  app.useGlobalInterceptors(new TransformResponseInterceptor());

  await app.listen(port);
  logger.log(`=======================================================`);
  logger.log(`🚀 CIMS Backend Server running on http://localhost:${port}/api/v1`);
  logger.log(`📡 Environment: ${configService.get('nodeEnv')}`);
  logger.log(`=======================================================`);
}

bootstrap();

