import { Body, Controller, ForbiddenException, Get, Param, Patch, Query, Req, UseGuards } from '@nestjs/common';
import { IsDateString, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireAnyPermissions, RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { OrderWorkService, OrderWorkRole, orderWorkRoles } from './order-work.service';

class AssignQualityDto {
  @IsUUID()
  user_id: string;

  @IsOptional()
  @IsDateString()
  target_date?: string;
}

class CheckQualityDto {
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

@Controller('order-work')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class OrderWorkController {
  constructor(private readonly work: OrderWorkService) {}

  @Get()
  @RequireAnyPermissions('permission.po.read', 'permission.production.read', 'permission.qc.check', 'permission.packing.update', 'permission.export.read')
  list(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Req() request: { department_codes: string[] },
    @Query('department') department: OrderWorkRole,
  ) {
    if (!orderWorkRoles.includes(department) || !request.department_codes.includes(department)) {
      throw new ForbiddenException();
    }
    return this.work.list(tenantId, userId, department);
  }

  @Get('staff')
  @RequirePermissions('permission.production.assign')
  staff(@CurrentTenant() tenantId: string) {
    return this.work.listStaff(tenantId);
  }

  @Get('accounts/:poId')
  @RequirePermissions('permission.po.read')
  detail(
    @CurrentTenant() tenantId: string,
    @Req() request: { department_codes: string[] },
    @Param('poId') poId: string,
  ) {
    if (!request.department_codes.includes('ACCOUNTS')) throw new ForbiddenException();
    return this.work.accountDetail(tenantId, poId);
  }

  @Patch(':poId/items/:itemId/quality-assignment')
  @RequirePermissions('permission.production.assign')
  assignQuality(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Param('poId') poId: string,
    @Param('itemId') itemId: string,
    @Body() dto: AssignQualityDto,
  ) {
    return this.work.assignQuality(tenantId, userId, poId, itemId, dto.user_id, dto.target_date);
  }

  @Patch(':poId/items/:itemId/quality-check')
  @RequirePermissions('permission.qc.check')
  checkQuality(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Param('poId') poId: string,
    @Param('itemId') itemId: string,
    @Body() dto: CheckQualityDto,
  ) {
    return this.work.checkQuality(tenantId, userId, poId, itemId, dto.note);
  }
}
