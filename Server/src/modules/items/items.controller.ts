import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
  ApiConsumes,
} from '@nestjs/swagger';
import { ItemsService } from './items.service';
import { StorageService } from '../storage/storage.service';
import { CreateItemDto } from './dtos/create-item.dto';
import { UpdateItemDto } from './dtos/update-item.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Items & Raw Materials')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant UUID',
  required: true,
})
@Controller('items')
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class ItemsController {
  constructor(
    private readonly itemsService: ItemsService,
    private readonly storageService: StorageService,
  ) {}

  @Post('upload-image')
  @RequireAnyPermissions('permission.item.create', 'permission.item.update')
  @UseInterceptors(FileInterceptor('image'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload item image',
    description: 'Uploads single image file for an item to AWS S3 or fallback storage.',
  })
  @ApiResponse({ status: 200, description: 'Image uploaded successfully' })
  async uploadImage(@UploadedFile() file: Express.Multer.File) {
    const imageUrl = await this.storageService.uploadFile(file, 'items');
    return { image_url: imageUrl };
  }

  @Post(':id/image')
  @RequirePermissions('permission.item.update')
  @UseInterceptors(FileInterceptor('image'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload and set item image',
    description: 'Uploads single image and attaches it directly to the specified item.',
  })
  @ApiResponse({ status: 200, description: 'Item image updated' })
  async updateItemImage(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const imageUrl = await this.storageService.uploadFile(file, 'items');
    return this.itemsService.updateImage(tenantId, itemId, imageUrl);
  }

  @Post()
  @RequirePermissions('permission.item.create')
  @ApiOperation({
    summary: 'Create new item',
    description: 'Registers a raw material, finished good, or packaging SKU. Enforces unique SKU per tenant.',
  })
  @ApiResponse({ status: 201, description: 'Item created' })
  @ApiResponse({ status: 409, description: 'SKU already exists in tenant' })
  async create(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateItemDto,
  ) {
    return this.itemsService.create(tenantId, dto);
  }

  @Get()
  @RequireAnyPermissions(
    'permission.item.read',
    'permission.item.create',
    'permission.item.update',
    'permission.item.delete',
  )
  @ApiOperation({
    summary: 'List all items',
    description: 'Returns all items with live available stock and reorder shortfall alert calculations.',
  })
  @ApiResponse({ status: 200, description: 'List of items with stock metrics' })
  async findAll(@CurrentTenant() tenantId: string) {
    return this.itemsService.findAll(tenantId);
  }

  @Get(':id')
  @RequireAnyPermissions(
    'permission.item.read',
    'permission.item.create',
    'permission.item.update',
    'permission.item.delete',
  )
  @ApiOperation({
    summary: 'Get item details',
    description: 'Returns item details and associated batches sorted by FEFO (First-Expired, First-Out).',
  })
  @ApiResponse({ status: 200, description: 'Item details with active batches' })
  @ApiResponse({ status: 404, description: 'Item not found' })
  async findOne(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
  ) {
    return this.itemsService.findOne(tenantId, itemId);
  }

  @Put(':id')
  @RequirePermissions('permission.item.update')
  @ApiOperation({ summary: 'Update item properties' })
  @ApiResponse({ status: 200, description: 'Item updated' })
  async update(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.itemsService.update(tenantId, itemId, dto);
  }

  @Delete(':id')
  @RequirePermissions('permission.item.delete')
  @ApiOperation({
    summary: 'Delete item',
    description: 'Deletes item. Blocks if active inventory batches still exist for this item.',
  })
  @ApiResponse({ status: 200, description: 'Item deleted' })
  @ApiResponse({ status: 400, description: 'Item has active batches in stock' })
  async remove(
    @CurrentTenant() tenantId: string,
    @Param('id') itemId: string,
  ) {
    return this.itemsService.remove(tenantId, itemId);
  }
}
