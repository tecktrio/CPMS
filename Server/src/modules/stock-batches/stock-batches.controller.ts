import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
  ApiQuery,
} from '@nestjs/swagger';
import { StockBatchesService } from './stock-batches.service';
import { CreateStockBatchDto } from './dtos/create-stock-batch.dto';
import { UpdateStockBatchDto } from './dtos/update-stock-batch.dto';
import { AllocateFefoDto } from './dtos/allocate-fefo.dto';
import { DeductBatchesDto } from './dtos/deduct-batches.dto';
import { BatchStatus } from '../../database/schemas/stock-batch.schema';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Stock Batches & FEFO Allocation')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant UUID',
  required: true,
})
@Controller('stock-batches')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class StockBatchesController {
  constructor(private readonly stockBatchesService: StockBatchesService) {}

  @Post()
  @RequirePermissions('permission.batch.create')
  @ApiOperation({
    summary: 'Inward batch receipt',
    description: 'Receives and stocks a new batch. Validates cold room capacity before accepting. Requires permission.batch.create.',
  })
  @ApiResponse({ status: 201, description: 'Batch created and stocked' })
  @ApiResponse({ status: 400, description: 'Room capacity exceeded or invalid dates' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateStockBatchDto,
  ) {
    return this.stockBatchesService.create(tenantId, dto);
  }

  @Get()
  @RequireAnyPermissions(
    'permission.batch.read',
    'permission.batch.create',
    'permission.batch.update',
    'permission.batch.deduct',
  )
  @ApiOperation({
    summary: 'List stock batches',
    description: 'Lists all inventory batches with optional filters, sorted by FEFO expiry date. Requires batch permission.',
  })
  @ApiQuery({ name: 'itemId', required: false })
  @ApiQuery({ name: 'storeRoomId', required: false })
  @ApiQuery({ name: 'status', enum: BatchStatus, required: false })
  @ApiResponse({ status: 200, description: 'List of matching batches' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async findAll(
    @CurrentTenant() tenantId: string,
    @Query('itemId') itemId?: string,
    @Query('storeRoomId') storeRoomId?: string,
    @Query('status') status?: BatchStatus,
  ) {
    return this.stockBatchesService.findAll(tenantId, {
      itemId,
      storeRoomId,
      status,
    });
  }

  @Get('expiring-soon')
  @RequireAnyPermissions(
    'permission.batch.read',
    'permission.batch.create',
    'permission.batch.update',
    'permission.batch.deduct',
  )
  @ApiOperation({
    summary: 'Get batches expiring soon',
    description: 'Returns active batches expiring within the specified days (default 7 days). Requires batch permission.',
  })
  @ApiQuery({ name: 'days', required: false, example: '7' })
  @ApiResponse({ status: 200, description: 'Batches nearing expiry date' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async findExpiringSoon(
    @CurrentTenant() tenantId: string,
    @Query('days') days?: string,
  ) {
    const daysThreshold = days ? parseInt(days, 10) : 7;
    return this.stockBatchesService.findExpiringSoon(tenantId, daysThreshold);
  }

  @Post('suggest-fefo')
  @RequirePermissions('permission.batch.deduct')
  @ApiOperation({
    summary: 'Calculate FEFO allocation suggestions',
    description: 'Evaluates non-expired inventory sorted by earliest expiry date and returns suggested batch picks with any shortfall calculated. Requires permission.batch.deduct.',
  })
  @ApiResponse({
    status: 200,
    description: 'FEFO suggested pick quantities across batches',
  })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async suggestFefo(
    @CurrentTenant() tenantId: string,
    @Body() dto: AllocateFefoDto,
  ) {
    return this.stockBatchesService.suggestFefoAllocation(tenantId, dto);
  }

  @Post('deduct-batches')
  @RequirePermissions('permission.batch.deduct')
  @ApiOperation({
    summary: 'Execute operator-confirmed batch deduction (Option B)',
    description: 'Allows operator to review, edit, and confirm exact batch deductions. Automatically marks fully depleted batches as DISPATCHED. Requires permission.batch.deduct.',
  })
  @ApiResponse({ status: 200, description: 'Batches deducted successfully' })
  @ApiResponse({ status: 400, description: 'Requested deduction exceeds available stock' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async deductBatches(
    @CurrentTenant() tenantId: string,
    @Body() dto: DeductBatchesDto,
  ) {
    return this.stockBatchesService.deductBatches(tenantId, dto);
  }

  @Get(':id')
  @RequireAnyPermissions(
    'permission.batch.read',
    'permission.batch.create',
    'permission.batch.update',
    'permission.batch.deduct',
  )
  @ApiOperation({ summary: 'Get stock batch details by ID' })
  @ApiResponse({ status: 200, description: 'Batch details' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') batchId: string,
  ) {
    return this.stockBatchesService.findOne(tenantId, batchId);
  }

  @Put(':id')
  @RequirePermissions('permission.batch.update')
  @ApiOperation({ summary: 'Update stock batch status or quantity' })
  @ApiResponse({ status: 200, description: 'Batch updated' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') batchId: string,
    @Body() dto: UpdateStockBatchDto,
  ) {
    return this.stockBatchesService.update(tenantId, batchId, dto);
  }
}
