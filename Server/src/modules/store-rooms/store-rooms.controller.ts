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
import { StoreRoomsService } from './store-rooms.service';
import { CreateStoreRoomDto } from './dtos/create-store-room.dto';
import { UpdateStoreRoomDto } from './dtos/update-store-room.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Store Rooms (Cold Storage)')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant UUID',
  required: true,
})
@Controller('store-rooms')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class StoreRoomsController {
  constructor(private readonly storeRoomsService: StoreRoomsService) {}

  @Post()
  @RequirePermissions('permission.storeroom.create')
  @ApiOperation({
    summary: 'Create store room / cold room',
    description: 'Creates a cold storage room. Enforces unique room_code per tenant. Requires permission.storeroom.create.',
  })
  @ApiResponse({ status: 201, description: 'Store room created' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  @ApiResponse({ status: 409, description: 'Room code already exists in tenant' })
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateStoreRoomDto,
  ) {
    return this.storeRoomsService.create(tenantId, dto);
  }

  @Get()
  @RequireAnyPermissions(
    'permission.storeroom.read',
    'permission.storeroom.create',
    'permission.storeroom.update',
    'permission.storeroom.delete',
  )
  @ApiOperation({
    summary: 'List all store rooms',
    description: 'Returns all cold storage rooms with live stock allocation and utilization percentage. Requires storeroom permission.',
  })
  @ApiResponse({ status: 200, description: 'List of cold rooms with capacity stats' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async findAll(@CurrentTenant() tenantId: string) {
    return this.storeRoomsService.findAll(tenantId);
  }

  @Get(':id')
  @RequireAnyPermissions(
    'permission.storeroom.read',
    'permission.storeroom.create',
    'permission.storeroom.update',
    'permission.storeroom.delete',
  )
  @ApiOperation({
    summary: 'Get store room details',
    description: 'Returns details and active inventory batch count for a specific cold room. Requires permission.storeroom.read.',
  })
  @ApiResponse({ status: 200, description: 'Store room details' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  @ApiResponse({ status: 404, description: 'Store room not found' })
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') storeRoomId: string,
  ) {
    return this.storeRoomsService.findOne(tenantId, storeRoomId);
  }

  @Put(':id')
  @RequirePermissions('permission.storeroom.update')
  @ApiOperation({
    summary: 'Update store room',
    description: 'Updates room properties. Capacity cannot be reduced below current allocated stock. Requires permission.storeroom.update.',
  })
  @ApiResponse({ status: 200, description: 'Store room updated' })
  @ApiResponse({ status: 400, description: 'Capacity underflow error' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') storeRoomId: string,
    @Body() dto: UpdateStoreRoomDto,
  ) {
    return this.storeRoomsService.update(tenantId, storeRoomId, dto);
  }

  @Delete(':id')
  @RequirePermissions('permission.storeroom.delete')
  @ApiOperation({
    summary: 'Deactivate store room',
    description: 'Deactivates room. Blocks if active inventory batches are currently stored inside. Requires permission.storeroom.delete.',
  })
  @ApiResponse({ status: 200, description: 'Store room deactivated' })
  @ApiResponse({ status: 400, description: 'Active batches present inside room' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async remove(
    @CurrentTenant() tenantId: string,
    @Param('id') storeRoomId: string,
  ) {
    return this.storeRoomsService.remove(tenantId, storeRoomId);
  }
}
