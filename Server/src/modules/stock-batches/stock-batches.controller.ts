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
import { StockBatchesService } from './stock-batches.service';
import { CreateStockBatchDto } from './dtos/create-stock-batch.dto';
import { UpdateStockBatchDto } from './dtos/update-stock-batch.dto';
import { AllocateFefoDto } from './dtos/allocate-fefo.dto';
import { DeductBatchesDto } from './dtos/deduct-batches.dto';
import { BatchStatus } from '../../database/schemas/stock-batch.schema';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@Controller('stock-batches')
@UseGuards(JwtAuthGuard, TenantGuard)
export class StockBatchesController {
  constructor(private readonly stockBatchesService: StockBatchesService) {}

  @Post()
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateStockBatchDto,
  ) {
    return this.stockBatchesService.create(tenantId, dto);
  }

  @Get()
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
  async findExpiringSoon(
    @CurrentTenant() tenantId: string,
    @Query('days') days?: string,
  ) {
    const daysThreshold = days ? parseInt(days, 10) : 7;
    return this.stockBatchesService.findExpiringSoon(tenantId, daysThreshold);
  }

  @Post('suggest-fefo')
  async suggestFefo(
    @CurrentTenant() tenantId: string,
    @Body() dto: AllocateFefoDto,
  ) {
    return this.stockBatchesService.suggestFefoAllocation(tenantId, dto);
  }

  @Post('deduct-batches')
  async deductBatches(
    @CurrentTenant() tenantId: string,
    @Body() dto: DeductBatchesDto,
  ) {
    return this.stockBatchesService.deductBatches(tenantId, dto);
  }

  @Get(':id')
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') batchId: string,
  ) {
    return this.stockBatchesService.findOne(tenantId, batchId);
  }

  @Put(':id')
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') batchId: string,
    @Body() dto: UpdateStockBatchDto,
  ) {
    return this.stockBatchesService.update(tenantId, batchId, dto);
  }
}

