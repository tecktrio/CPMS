import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
} from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Users Directory')
@ApiBearerAuth('jwt-auth')
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @UseGuards(TenantGuard, PermissionsGuard)
  @RequireAnyPermissions(
    'permission.user.read',
    'permission.user.add',
    'permission.user.update',
    'permission.user.delete',
    'permission.department.read',
    'permission.department.create',
    'permission.department.update',
    'permission.department.delete',
  )
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Active tenant UUID',
    required: true,
  })
  @ApiOperation({
    summary: 'List users in active tenant',
    description: 'Returns all users having active memberships in the specified organization. Requires permission.user.read.',
  })
  @ApiResponse({ status: 200, description: 'List of tenant users' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async findAllInTenant(@CurrentTenant() tenantId: string) {
    return this.usersService.findAllInTenant(tenantId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user profile by user_id' })
  @ApiResponse({ status: 200, description: 'User profile' })
  async findOne(@Param('id') userId: string) {
    return this.usersService.findOne(userId);
  }
}
