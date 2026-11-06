import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  Headers,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
} from '@nestjs/swagger';
import { TenantsService } from './tenants.service';
import { CreateTenantDto } from './dtos/create-tenant.dto';
import { InviteUserDto } from './dtos/invite-user.dto';
import { AddUserDto } from './dtos/add-user.dto';
import { UpdateTenantUserDto } from './dtos/update-tenant-user.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Tenants')
@ApiBearerAuth('jwt-auth')
@Controller('tenants')
@UseGuards(JwtAuthGuard)
export class TenantsController {
  constructor(private readonly tenantsService: TenantsService) {}

  @Post()
  @ApiOperation({
    summary: 'Create a new tenant organization',
    description: 'Registers a new tenant. The calling user is established as the Tenant Admin.',
  })
  @ApiResponse({ status: 201, description: 'Tenant created successfully' })
  async createTenant(
    @CurrentUser('user_id') userId: string,
    @Body() dto: CreateTenantDto,
  ) {
    return this.tenantsService.createTenant(userId, dto);
  }

  @Get()
  @ApiOperation({
    summary: "List current user's tenants",
    description: 'Returns all organizations the authenticated user holds an active membership in (powers the mobile Tenant Selector).',
  })
  @ApiResponse({ status: 200, description: 'List of accessible tenants' })
  async getUserTenants(@CurrentUser('user_id') userId: string) {
    return this.tenantsService.getUserTenants(userId);
  }

  @Get(':id/permissions')
  @ApiOperation({
    summary: 'Get current user aggregated permissions and active departments in tenant',
    description:
      'Returns the authenticated user active departments and calculated permissions in this tenant context.',
  })
  @ApiResponse({ status: 200, description: 'User permissions and assigned departments' })
  async getPermissions(
    @Param('id') tenantId: string,
    @CurrentUser('user_id') userId: string,
  ) {
    return this.tenantsService.getMyPermissions(tenantId, userId);
  }

  @Get(':id/my-permissions')
  @ApiOperation({
    summary: 'Get current user aggregated permissions and active departments in tenant (alias)',
  })
  async getMyPermissions(
    @Param('id') tenantId: string,
    @CurrentUser('user_id') userId: string,
  ) {
    return this.tenantsService.getMyPermissions(tenantId, userId);
  }

  @Get(':id/operations')
  @ApiOperation({
    summary: 'Get current user allowed operations in tenant',
  })
  async getOperations(
    @Param('id') tenantId: string,
    @CurrentUser('user_id') userId: string,
  ) {
    return this.tenantsService.getMyPermissions(tenantId, userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get tenant details and user permissions by ID' })
  @ApiResponse({ status: 200, description: 'Tenant details and user permissions' })
  async getTenantById(
    @Param('id') tenantId: string,
    @CurrentUser('user_id') userId: string,
  ) {
    return this.tenantsService.getTenantById(tenantId, userId);
  }

  @Post('add-user')
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Target tenant ID (optional if specified in request body)',
    required: false,
  })
  @ApiOperation({
    summary: 'Add user to tenant organization',
    description:
      'Tenant admin adds a user by providing the tenant ID, email address, and an array of department IDs. Assigning multiple departments to a single user is fully supported.',
  })
  @ApiResponse({
    status: 201,
    description: 'User successfully added/updated in tenant with assigned departments',
  })
  @ApiResponse({ status: 403, description: 'Only Tenant Admin can add users' })
  @ApiResponse({ status: 404, description: 'Tenant not found' })
  async addUser(
    @CurrentUser('user_id') userId: string,
    @Body() dto: AddUserDto,
    @Headers('x-tenant-id') headerTenantId?: string,
  ) {
    return this.tenantsService.addUserToTenant(headerTenantId, userId, dto);
  }

  @Post('invite')
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Target tenant ID (optional if specified in body)',
    required: false,
  })
  @ApiOperation({
    summary: 'Invite user into tenant (alias for add-user)',
    description: 'Tenant admin invites/adds a user by email and assigns departments.',
  })
  @ApiResponse({ status: 201, description: 'User membership created' })
  async inviteUser(
    @CurrentUser('user_id') userId: string,
    @Body() dto: InviteUserDto,
    @Headers('x-tenant-id') tenantId?: string,
  ) {
    return this.tenantsService.inviteUser(tenantId || '', userId, dto);
  }

  @Put('users/:userId')
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Target tenant ID (optional if specified in request body)',
    required: false,
  })
  @ApiOperation({
    summary: 'Update tenant user department allocations',
    description:
      'Tenant admin updates the department assignments of an existing member in the tenant organization. Validates that all departments exist and are active in this tenant.',
  })
  @ApiResponse({
    status: 200,
    description: 'User department assignments updated successfully',
  })
  @ApiResponse({ status: 400, description: 'Invalid department IDs provided' })
  @ApiResponse({ status: 403, description: 'Only Tenant Admin can update users' })
  @ApiResponse({ status: 404, description: 'User or tenant membership not found' })
  async updateTenantUser(
    @CurrentUser('user_id') requestingUserId: string,
    @Param('userId') targetUserId: string,
    @Body() dto: UpdateTenantUserDto,
    @Headers('x-tenant-id') headerTenantId?: string,
  ) {
    return this.tenantsService.updateTenantUser(
      headerTenantId,
      requestingUserId,
      targetUserId,
      dto,
    );
  }

  @Delete('users/:userId')
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Target tenant organization UUID',
    required: true,
  })
  @ApiOperation({
    summary: 'Remove user from tenant organization',
    description:
      'Tenant admin removes a user completely from the tenant organization (deactivates membership and strips all department assignments). Cannot remove tenant admin.',
  })
  @ApiResponse({
    status: 200,
    description: 'User successfully removed from tenant organization',
  })
  @ApiResponse({
    status: 400,
    description: 'Cannot remove tenant admin from their own tenant',
  })
  @ApiResponse({ status: 403, description: 'Only Tenant Admin can remove users' })
  @ApiResponse({ status: 404, description: 'User membership not found' })
  async removeUserFromTenant(
    @CurrentUser('user_id') requestingUserId: string,
    @Param('userId') targetUserId: string,
    @Headers('x-tenant-id') headerTenantId: string,
  ) {
    return this.tenantsService.removeUserFromTenant(
      headerTenantId,
      requestingUserId,
      targetUserId,
    );
  }

  @Delete('users/:userId/departments/:departmentId')
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Target tenant organization UUID',
    required: true,
  })
  @ApiOperation({
    summary: 'Remove user from a specific department',
    description:
      'Removes a single department assignment from a user without affecting their other department roles in the tenant.',
  })
  @ApiResponse({
    status: 200,
    description: 'User successfully removed from the specified department',
  })
  @ApiResponse({
    status: 403,
    description: 'Only Tenant Admin can modify department assignments',
  })
  @ApiResponse({
    status: 404,
    description: 'User membership or department assignment not found',
  })
  async removeUserFromDepartment(
    @CurrentUser('user_id') requestingUserId: string,
    @Param('userId') targetUserId: string,
    @Param('departmentId') departmentId: string,
    @Headers('x-tenant-id') headerTenantId: string,
  ) {
    return this.tenantsService.removeUserFromDepartment(
      headerTenantId,
      requestingUserId,
      targetUserId,
      departmentId,
    );
  }
}
