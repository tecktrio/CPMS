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
import { ItemsService } from './items.service';
import { CreateItemDto } from './dtos/create-item.dto';
import { UpdateItemDto } from './dtos/update-item.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@Controller('items')
@UseGuards(JwtAuthGuard, TenantGuard)
export class ItemsController {
  constructor(private readonly itemsService: ItemsService) {}

  @Post()
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateItemDto,
  ) {
    return this.itemsService.create(tenantId, dto);
  }

  @Get()
  async findAll(@CurrentTenant() tenantId: string) {
    return this.itemsService.findAll(tenantId);
  }

  @Get(':id')
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
  ) {
    return this.itemsService.findOne(tenantId, itemId);
  }

  @Put(':id')
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.itemsService.update(tenantId, itemId, dto);
  }

  @Delete(':id')
  async remove(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
  ) {
    return this.itemsService.remove(tenantId, itemId);
  }
}

