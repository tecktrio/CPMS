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
import { StoreRoomsService } from './store-rooms.service';
import { CreateStoreRoomDto } from './dtos/create-store-room.dto';
import { UpdateStoreRoomDto } from './dtos/update-store-room.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@Controller('store-rooms')
@UseGuards(JwtAuthGuard, TenantGuard)
export class StoreRoomsController {
  constructor(private readonly storeRoomsService: StoreRoomsService) {}

  @Post()
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateStoreRoomDto,
  ) {
    return this.storeRoomsService.create(tenantId, dto);
  }

  @Get()
  async findAll(@CurrentTenant() tenantId: string) {
    return this.storeRoomsService.findAll(tenantId);
  }

  @Get(':id')
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') storeRoomId: string,
  ) {
    return this.storeRoomsService.findOne(tenantId, storeRoomId);
  }

  @Put(':id')
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') storeRoomId: string,
    @Body() dto: UpdateStoreRoomDto,
  ) {
    return this.storeRoomsService.update(tenantId, storeRoomId, dto);
  }

  @Delete(':id')
  async remove(
    @CurrentTenant() tenantId: string,
    @Param('id') storeRoomId: string,
  ) {
    return this.storeRoomsService.remove(tenantId, storeRoomId);
  }
}

