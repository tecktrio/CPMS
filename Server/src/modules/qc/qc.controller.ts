import {
  Controller,
  Get,
  Post,
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
import { QcService } from './qc.service';
import { CreateQcReportDto } from './dtos/create-qc-report.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Quality Control (QC)')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant organization UUID',
  required: true,
})
@Controller('qc')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class QcController {
  constructor(private readonly qcService: QcService) {}

  @Post('reports')
  @RequirePermissions('permission.qc.create')
  @ApiOperation({ summary: 'Submit inspection report for PO item' })
  async createReport(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Body() dto: CreateQcReportDto,
  ) {
    return this.qcService.createReport(tenantId, userId, dto);
  }

  @Get('reports/po/:poId')
  @RequirePermissions('permission.qc.read')
  @ApiOperation({ summary: 'Get all QC inspection reports for a PO' })
  async getReportsByPo(
    @CurrentTenant() tenantId: string,
    @Param('poId') poId: string,
  ) {
    return this.qcService.getReportsByPo(tenantId, poId);
  }

  @Get('reports/:id')
  @RequirePermissions('permission.qc.read')
  @ApiOperation({ summary: 'Get a specific QC inspection report' })
  async getReportById(
    @CurrentTenant() tenantId: string,
    @Param('id') reportId: string,
  ) {
    return this.qcService.getReportById(tenantId, reportId);
  }
}

