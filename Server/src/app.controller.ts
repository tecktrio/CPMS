import { Controller, Get, Head } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { InjectConnection } from '@nestjs/mongoose';
import { Connection } from 'mongoose';

@ApiTags('Health')
@Controller()
export class AppController {
  constructor(@InjectConnection() private readonly connection: Connection) {}

  @Get()
  @Head()
  @ApiOperation({ summary: 'Root service status check' })
  @ApiResponse({ status: 200, description: 'Service is active' })
  getRoot() {
    return {
      status: 'ok',
      service: 'Cyan Product Management System (CPMS) API',
      version: '1.0.1',
      database: this.connection.readyState === 1 ? 'connected' : 'disconnected',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('api/health')
  @Head('api/health')
  @ApiOperation({ summary: 'Health check endpoint' })
  @ApiResponse({ status: 200, description: 'Health check passed' })
  getApiHealth() {
    return {
      status: 'ok',
      service: 'CPMS Backend API',
      database: this.connection.readyState === 1 ? 'connected' : 'disconnected',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('health')
  @Head('health')
  @ApiOperation({ summary: 'Standard health check endpoint' })
  @ApiResponse({ status: 200, description: 'Health check passed' })
  getHealth() {
    return {
      status: 'ok',
      service: 'CPMS Backend API',
      database: this.connection.readyState === 1 ? 'connected' : 'disconnected',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('api/v1/health')
  @Head('api/v1/health')
  @ApiOperation({ summary: 'Versioned health check endpoint' })
  @ApiResponse({ status: 200, description: 'Health check passed' })
  getVersionedHealth() {
    return {
      status: 'ok',
      service: 'CPMS Backend API v1',
      database: this.connection.readyState === 1 ? 'connected' : 'disconnected',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }
}

