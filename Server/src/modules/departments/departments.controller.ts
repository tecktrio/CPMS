import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
} from '@nestjs/swagger';
import { DepartmentsService } from './departments.service';
import { CreateDepartmentDto } from './dtos/create-department.dto';
import { UpdateDepartmentDto } from './dtos/update-department.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Departments & RBAC')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant organization UUID',
  required: true,
})
@Controller('departments')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class DepartmentsController {
  constructor(private readonly departmentsService: DepartmentsService) {}

  @Post()
  @RequirePermissions('permission.department.create')
  @ApiOperation({
    summary: 'Create new department',
    description:
      'Creates a functional department within the active tenant and allocates specific permission IDs. Enforces unique department name per organization. Requires permission.department.create.',
  })
  @ApiResponse({ status: 201, description: 'Department created successfully' })
  @ApiResponse({ status: 400, description: 'Invalid permission IDs provided' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  @ApiResponse({ status: 409, description: 'Department name already exists in tenant' })
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateDepartmentDto,
  ) {
    return this.departmentsService.create(tenantId, dto);
  }

  @Get()
  @ApiOperation({
    summary: 'List all tenant departments',
    description:
      'Returns all active departments for the specified tenant, including allocated permission IDs.',
  })
  @ApiResponse({ status: 200, description: 'List of departments' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing tenant context' })
  async findAll(@CurrentTenant() tenantId: string) {
    return this.departmentsService.findAll(tenantId);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get department details',
    description: 'Retrieves department configuration, metadata, and permission IDs.',
  })
  @ApiResponse({ status: 200, description: 'Department details' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing tenant context' })
  @ApiResponse({ status: 404, description: 'Department not found' })
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') departmentId: string,
  ) {
    return this.departmentsService.findOne(tenantId, departmentId);
  }

  @Put(':id')
  @RequirePermissions('permission.department.update')
  @ApiOperation({
    summary: 'Update department',
    description:
      'Updates department name, description, and/or allocated permission IDs. Requires permission.department.update.',
  })
  @ApiResponse({ status: 200, description: 'Department updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  @ApiResponse({ status: 404, description: 'Department not found' })
  @ApiResponse({ status: 409, description: 'Duplicate department name' })
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') departmentId: string,
    @Body() dto: UpdateDepartmentDto,
  ) {
    return this.departmentsService.update(tenantId, departmentId, dto);
  }

  @Delete(':id')
  @RequirePermissions('permission.department.delete')
  @ApiOperation({
    summary: 'Deactivate department',
    description: 'Soft-deletes / deactivates the department. Requires permission.department.delete.',
  })
  @ApiResponse({ status: 200, description: 'Department deactivated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  @ApiResponse({ status: 404, description: 'Department not found' })
  async delete(
    @CurrentTenant() tenantId: string,
    @Param('id') departmentId: string,
  ) {
    return this.departmentsService.delete(tenantId, departmentId);
  }
}

