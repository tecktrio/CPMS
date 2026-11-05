import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { PermissionsService } from './permissions.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('System Permissions')
@ApiBearerAuth('jwt-auth')
@Controller('permissions')
@UseGuards(JwtAuthGuard)
export class PermissionsController {
  constructor(private readonly permissionsService: PermissionsService) {}

  @Get()
  @ApiOperation({
    summary: 'List all available system permissions',
    description:
      'Returns system permissions with module categorization. Used when creating or editing a department to allocate permissions.',
  })
  @ApiQuery({
    name: 'grouped',
    required: false,
    type: Boolean,
    description: 'Set to true to group permissions by module name',
  })
  @ApiResponse({
    status: 200,
    description: 'List of system permissions',
  })
  async findAll(@Query('grouped') grouped?: string) {
    if (grouped === 'true' || grouped === '1') {
      return this.permissionsService.getGroupedByModule();
    }
    return this.permissionsService.findAll();
  }
}

