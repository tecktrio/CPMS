import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformResponseInterceptor } from './common/interceptors/transform-response.interceptor';

async function bootstrap() {
  const logger = new Logger('CPMS-Bootstrap');
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

  // Swagger OpenAPI Documentation Setup
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Cyan Product Management System (CPMS) API')
    .setDescription(
      'Interactive REST API documentation for CPMS food production management, store room inventory, and stock allocation platform.',
    )
    .setVersion('1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'Authorization',
        description:
          'Enter your JWT access token (e.g. eyJhbGciOi... — Swagger UI will automatically prepend "Bearer ")',
        in: 'header',
      },
      'jwt-auth',
    )
    .addSecurityRequirements('jwt-auth')
    .addApiKey(
      {
        type: 'apiKey',
        name: 'X-Tenant-ID',
        in: 'header',
        description: 'Tenant UUID (obtained after login via available_tenants)',
      },
      'tenant-id',
    )
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
    },
    customSiteTitle: 'CPMS API Documentation',
  });

  await app.listen(port, '0.0.0.0');
  logger.log(`=======================================================`);
  logger.log(`🚀 CPMS Backend Server running on: http://0.0.0.0:${port}/api/v1`);
  logger.log(`📚 Swagger API Docs available at:  http://0.0.0.0:${port}/api/docs`);
  logger.log(`📡 Environment: ${configService.get('nodeEnv')}`);
  logger.log(`=======================================================`);
}

bootstrap();
