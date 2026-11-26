import {
  Controller,
  Get,
  Post,
  Patch,
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
import { ProductionService } from './production.service';
import {
  CreateProductionAssignmentDto,
  UpdateAssignmentDto,
  UpdateProgressDto,
} from './dtos/production-assignment.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Production')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant organization UUID',
  required: true,
})
@Controller('production')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class ProductionController {
  constructor(private readonly productionService: ProductionService) {}

  @Post('assignments')
  @RequirePermissions('permission.production.create')
  @ApiOperation({ summary: 'Assign supervisor to PO item' })
  async createAssignment(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Body() dto: CreateProductionAssignmentDto,
  ) {
    return this.productionService.createAssignment(tenantId, userId, dto);
  }

  @Get('assignments')
  @RequirePermissions('permission.production.read')
  @ApiOperation({ summary: 'List all production assignments' })
  async getAllAssignments(@CurrentTenant() tenantId: string) {
    return this.productionService.getAllAssignments(tenantId);
  }

  @Get('assignments/my')
  @RequirePermissions('permission.production.read')
  @ApiOperation({ summary: 'Get current supervisor tasks' })
  async getMyAssignments(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
  ) {
    return this.productionService.getMyAssignments(tenantId, userId);
  }

  @Get('assignments/po/:poId')
  @RequirePermissions('permission.production.read')
  @ApiOperation({ summary: 'Get assignments for a specific PO' })
  async getAssignmentsByPo(
    @CurrentTenant() tenantId: string,
    @Param('poId') poId: string,
  ) {
    return this.productionService.getAssignmentsByPo(tenantId, poId);
  }

  @Patch('assignments/:id')
  @RequirePermissions('permission.production.update')
  @ApiOperation({ summary: 'Reassign supervisor, update quantity or notes on assignment' })
  async updateAssignment(
    @CurrentTenant() tenantId: string,
    @Param('id') assignmentId: string,
    @Body() dto: UpdateAssignmentDto,
  ) {
    return this.productionService.updateAssignment(tenantId, assignmentId, dto);
  }

  @Patch('assignments/:id/progress')
  @RequirePermissions('permission.production.update')
  @ApiOperation({ summary: 'Supervisor logs progress on assigned line item' })
  async updateProgress(
    @CurrentTenant() tenantId: string,
    @Param('id') assignmentId: string,
    @CurrentUser('user_id') userId: string,
    @Body() dto: UpdateProgressDto,
  ) {
    return this.productionService.updateProgress(
      tenantId,
      assignmentId,
      userId,
      dto,
    );
  }

  @Delete('assignments/:id')
  @RequirePermissions('permission.production.delete')
  @ApiOperation({ summary: 'Cancel/remove a production assignment' })
  async cancelAssignment(
    @CurrentTenant() tenantId: string,
    @Param('id') assignmentId: string,
  ) {
    return this.productionService.cancelAssignment(tenantId, assignmentId);
  }
}

