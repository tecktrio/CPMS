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
import {
  CreateItemCategoryDto,
  UpdateItemCategoryDto,
} from './dtos/item-category.dto';
import {
  CreatePackagingMaterialDto,
  UpdatePackagingMaterialDto,
} from './dtos/packaging-material.dto';
import { ReassignCountryDto } from './dtos/reassign-country.dto';
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

  // --- ITEM CATEGORIES ENDPOINTS ---

  @Get('categories/all')
  @RequireAnyPermissions(
    'permission.item.read',
    'permission.item.create',
    'permission.item.update',
    'permission.item_category.manage',
  )
  @ApiOperation({ summary: 'List all item categories for tenant' })
  @ApiResponse({ status: 200, description: 'List of item categories' })
  async getCategories(@CurrentTenant() tenantId: string) {
    return this.itemsService.getCategories(tenantId);
  }

  @Post('categories')
  @RequirePermissions('permission.item_category.manage')
  @ApiOperation({ summary: 'Create a new item category' })
  @ApiResponse({ status: 201, description: 'Item category created' })
  async createCategory(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateItemCategoryDto,
  ) {
    return this.itemsService.createCategory(tenantId, dto);
  }

  @Put('categories/:code')
  @RequirePermissions('permission.item_category.manage')
  @ApiOperation({ summary: 'Update an existing item category' })
  @ApiResponse({ status: 200, description: 'Item category updated' })
  async updateCategory(
    @CurrentTenant() tenantId: string,
    @Param('code') code: string,
    @Body() dto: UpdateItemCategoryDto,
  ) {
    return this.itemsService.updateCategory(tenantId, code, dto);
  }

  @Get('categories/:code/items-count')
  @RequirePermissions('permission.item_category.manage')
  @ApiOperation({ summary: 'Get count of items in category before deletion' })
  @ApiResponse({ status: 200, description: 'Items count for category' })
  async getCategoryItemsCount(
    @CurrentTenant() tenantId: string,
    @Param('code') code: string,
  ) {
    return this.itemsService.checkCategoryItemsCount(tenantId, code);
  }

  @Delete('categories/:code')
  @RequirePermissions('permission.item_category.manage')
  @ApiOperation({
    summary: 'Delete category and all associated items cascade',
  })
  @ApiResponse({ status: 200, description: 'Category and items deleted' })
  async deleteCategory(
    @CurrentTenant() tenantId: string,
    @Param('code') code: string,
  ) {
    return this.itemsService.deleteCategory(tenantId, code);
  }

  // --- PACKAGING MATERIALS ENDPOINTS ---

  @Get('packaging-materials/all')
  @RequireAnyPermissions(
    'permission.item.read',
    'permission.item.create',
    'permission.item.update',
    'permission.packaging_material.manage',
  )
  @ApiOperation({ summary: 'List all packaging materials for tenant' })
  @ApiResponse({ status: 200, description: 'List of packaging materials' })
  async getPackagingMaterials(@CurrentTenant() tenantId: string) {
    return this.itemsService.getPackagingMaterials(tenantId);
  }

  @Post('packaging-materials')
  @RequirePermissions('permission.packaging_material.manage')
  @ApiOperation({ summary: 'Create a new packaging material' })
  @ApiResponse({ status: 201, description: 'Packaging material created' })
  async createPackagingMaterial(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreatePackagingMaterialDto,
  ) {
    return this.itemsService.createPackagingMaterial(tenantId, dto);
  }

  @Put('packaging-materials/:id')
  @RequirePermissions('permission.packaging_material.manage')
  @ApiOperation({ summary: 'Update packaging material name' })
  @ApiResponse({ status: 200, description: 'Packaging material updated' })
  async updatePackagingMaterial(
    @CurrentTenant() tenantId: string,
    @Param('id') id: string,
    @Body() dto: UpdatePackagingMaterialDto,
  ) {
    return this.itemsService.updatePackagingMaterial(tenantId, id, dto);
  }

  @Get('packaging-materials/:id/items-count')
  @RequirePermissions('permission.packaging_material.manage')
  @ApiOperation({ summary: 'Get count of items using this packaging material' })
  @ApiResponse({ status: 200, description: 'Items count for packaging material' })
  async getPackagingMaterialItemsCount(
    @CurrentTenant() tenantId: string,
    @Param('id') id: string,
  ) {
    return this.itemsService.checkPackagingMaterialItemsCount(tenantId, id);
  }

  @Delete('packaging-materials/:id')
  @RequirePermissions('permission.packaging_material.manage')
  @ApiOperation({
    summary: 'Delete packaging material and all associated items cascade',
  })
  @ApiResponse({
    status: 200,
    description: 'Packaging material and items deleted',
  })
  async deletePackagingMaterial(
    @CurrentTenant() tenantId: string,
    @Param('id') id: string,
  ) {
    return this.itemsService.deletePackagingMaterial(tenantId, id);
  }

  // --- COUNTRY REASSIGN / RENAME ---

  @Put('countries/reassign')
  @RequireAnyPermissions('permission.item.update', 'permission.item_category.manage')
  @ApiOperation({
    summary: 'Reassign or rename country for all matching items in tenant',
  })
  @ApiResponse({
    status: 200,
    description: 'Items country reassigned successfully',
  })
  async reassignCountry(
    @CurrentTenant() tenantId: string,
    @Body() dto: ReassignCountryDto,
  ) {
    return this.itemsService.reassignCountry(
      tenantId,
      dto.from_country,
      dto.to_country,
    );
  }
}
