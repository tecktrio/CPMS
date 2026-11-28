import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import { Item, ItemDocument } from '../../database/schemas/item.schema';
import {
  ItemCategory,
  ItemCategoryDocument,
} from '../../database/schemas/item-category.schema';
import {
  PackagingMaterial,
  PackagingMaterialDocument,
} from '../../database/schemas/packaging-material.schema';
import {
  StoreRoom,
  StoreRoomDocument,
} from '../../database/schemas/store-room.schema';
import {
  StockBatch,
  StockBatchDocument,
  BatchStatus,
} from '../../database/schemas/stock-batch.schema';
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
import { StorageService } from '../storage/storage.service';

function normalizeIngredients(ingredients?: any[]): Array<{ item_id: string; quantity: number; unit?: string }> {
  if (!ingredients || !Array.isArray(ingredients)) return [];
  return ingredients.map((ing) => {
    if (typeof ing === 'string') {
      return { item_id: ing, quantity: 1, unit: '' };
    }
    return {
      item_id: ing?.item_id || '',
      quantity: typeof ing?.quantity === 'number' ? ing.quantity : parseFloat(ing?.quantity) || 1,
      unit: ing?.unit || '',
    };
  });
}

@Injectable()
export class ItemsService {
  constructor(
    @InjectModel(Item.name)
    private readonly itemModel: Model<ItemDocument>,
    @InjectModel(ItemCategory.name)
    private readonly itemCategoryModel: Model<ItemCategoryDocument>,
    @InjectModel(PackagingMaterial.name)
    private readonly packagingMaterialModel: Model<PackagingMaterialDocument>,
    @InjectModel(StoreRoom.name)
    private readonly storeRoomModel: Model<StoreRoomDocument>,
    @InjectModel(StockBatch.name)
    private readonly batchModel: Model<StockBatchDocument>,
    private readonly storageService: StorageService,
  ) {}

  async create(tenantId: string, dto: CreateItemDto) {
    const skuNormalized = dto.sku.trim().toUpperCase();

    // Verify SKU uniqueness within this tenant
    const existing = await this.itemModel.findOne({
      tenant_id: tenantId,
      sku: skuNormalized,
    });

    if (existing) {
      throw new ConflictException(
        `An item with code '${skuNormalized}' already exists in your organization`,
      );
    }

    const newItem = new this.itemModel({
      item_id: uuidv4(),
      tenant_id: tenantId,
      sku: skuNormalized,
      item_name: dto.item_name.trim(),
      item_type: dto.item_type,
      measurement_unit: dto.measurement_unit,
      packing_material: dto.packing_material?.trim(),
      quantity: dto.quantity ?? 1,
      reorder_threshold_quantity: dto.reorder_threshold_quantity ?? 0,
      description: dto.description || '',
      has_ingredients: dto.has_ingredients ?? false,
      ingredients: normalizeIngredients(dto.ingredients),
      image_url: dto.image_url || null,
      is_active: true,
    });

    await newItem.save();
    return newItem;
  }

  async findAll(tenantId: string) {
    const items = await this.itemModel
      .find({ tenant_id: tenantId })
      .sort({ item_name: 1 });

    // Aggregate inventory count and reorder alert status per item
    const results = await Promise.all(
      items.map(async (item) => {
        const batches = await this.batchModel.find({
          tenant_id: tenantId,
          item_id: item.item_id,
          batch_status: BatchStatus.AVAILABLE,
          expiry_date: { $gt: new Date() },
        });

        const batchStock = batches.reduce(
          (sum, b) => sum + (b.available_quantity || 0),
          0,
        );

        const rooms = await this.storeRoomModel.find({
          tenant_id: tenantId,
          'items.item_id': item.item_id,
        });

        const roomStock = rooms.reduce((roomSum, r) => {
          const itemEntries = (r.items || []).filter((it) => it.item_id === item.item_id);
          return roomSum + itemEntries.reduce((s, it) => s + (it.quantity || 0), 0);
        }, 0);

        const configuredMinimumStock = rooms.reduce((minimumSum, r) => {
          const itemEntries = (r.items || []).filter((it) => it.item_id === item.item_id);
          return minimumSum + itemEntries.reduce((s, it) => s + (it.min_count || 0), 0);
        }, 0);

        const totalStock = roomStock > 0 ? roomStock : batchStock;
        const minimumStock = configuredMinimumStock > 0
          ? configuredMinimumStock
          : item.reorder_threshold_quantity;

        const isBelowThreshold =
          totalStock < minimumStock;

        const shortfall = isBelowThreshold
          ? Math.max(0, minimumStock - totalStock)
          : 0;

        return {
          ...item.toObject(),
          total_available_stock: totalStock,
          current_stock_quantity: totalStock,
          minimum_stock_count: minimumStock,
          active_batches_count: batches.length,
          is_below_reorder_threshold: isBelowThreshold,
          reorder_shortfall_quantity: shortfall,
          store_rooms: rooms.map((r) => ({
            store_room_id: r.store_room_id,
            room_name: r.room_name,
            room_code: r.room_code,
          })),
        };
      }),
    );

    return results;
  }

  async findOne(tenantId: string, itemId: string) {
    const item = await this.itemModel.findOne({
      tenant_id: tenantId,
      item_id: itemId,
    });

    if (!item) {
      throw new NotFoundException('Item not found');
    }

    const batches = await this.batchModel
      .find({
        tenant_id: tenantId,
        item_id: itemId,
      })
      .sort({ expiry_date: 1 }); // Sorted by FEFO order

    const totalBatchStock = batches
      .filter(
        (b) =>
          b.batch_status === BatchStatus.AVAILABLE &&
          new Date(b.expiry_date) > new Date(),
      )
      .reduce((sum, b) => sum + (b.available_quantity || 0), 0);

    const rooms = await this.storeRoomModel.find({
      tenant_id: tenantId,
      'items.item_id': itemId,
    });

    const roomStock = rooms.reduce((roomSum, r) => {
      const itemEntries = (r.items || []).filter((it) => it.item_id === itemId);
      return roomSum + itemEntries.reduce((s, it) => s + (it.quantity || 0), 0);
    }, 0);

    const configuredMinimumStock = rooms.reduce((minimumSum, r) => {
      const itemEntries = (r.items || []).filter((it) => it.item_id === itemId);
      return minimumSum + itemEntries.reduce((s, it) => s + (it.min_count || 0), 0);
    }, 0);

    const totalAvailableStock = roomStock > 0 ? roomStock : totalBatchStock;
    const minimumStock = configuredMinimumStock > 0
      ? configuredMinimumStock
      : item.reorder_threshold_quantity;

    const isBelowThreshold =
      totalAvailableStock < minimumStock;

    return {
      ...item.toObject(),
      total_available_stock: totalAvailableStock,
      current_stock_quantity: totalAvailableStock,
      minimum_stock_count: minimumStock,
      is_below_reorder_threshold: isBelowThreshold,
      reorder_shortfall_quantity: isBelowThreshold
        ? minimumStock - totalAvailableStock
        : 0,
      batches,
      store_rooms: rooms.map((r) => ({
        store_room_id: r.store_room_id,
        room_name: r.room_name,
        room_code: r.room_code,
        items: (r.items || []).filter((it) => it.item_id === itemId),
      })),
    };
  }

  async update(tenantId: string, itemId: string, dto: UpdateItemDto) {
    const item = await this.itemModel.findOne({
      tenant_id: tenantId,
      item_id: itemId,
    });

    if (!item) {
      throw new NotFoundException('Item not found');
    }

    if (dto.sku && dto.sku.trim().toUpperCase() !== item.sku) {
      const skuNormalized = dto.sku.trim().toUpperCase();
      const existing = await this.itemModel.findOne({
        tenant_id: tenantId,
        sku: skuNormalized,
        item_id: { $ne: itemId },
      });
      if (existing) {
        throw new ConflictException(
          `Item with code '${skuNormalized}' already exists`,
        );
      }
      item.sku = skuNormalized;
    }

    if (dto.item_name !== undefined) item.item_name = dto.item_name.trim();
    if (dto.item_type !== undefined) item.item_type = dto.item_type;
    if (dto.measurement_unit !== undefined)
      item.measurement_unit = dto.measurement_unit;
    if (dto.packing_material !== undefined)
      item.packing_material = dto.packing_material?.trim() ?? '';
    if (dto.quantity !== undefined) item.quantity = dto.quantity;
    if (dto.reorder_threshold_quantity !== undefined)
      item.reorder_threshold_quantity = dto.reorder_threshold_quantity;
    if (dto.image_url !== undefined && dto.image_url !== item.image_url) {
      if (item.image_url) {
        await this.storageService.deleteFile(item.image_url);
      }
      item.image_url = dto.image_url;
    }
    if (dto.is_active !== undefined) item.is_active = dto.is_active;
    if (dto.description !== undefined) item.description = dto.description;
    if (dto.has_ingredients !== undefined) item.has_ingredients = dto.has_ingredients;
    if (dto.ingredients !== undefined) item.ingredients = normalizeIngredients(dto.ingredients);

    await item.save();
    return item;
  }

  async remove(tenantId: string, itemId: string) {
    const item = await this.itemModel.findOne({
      tenant_id: tenantId,
      item_id: itemId,
    });

    if (!item) {
      throw new NotFoundException('Item not found');
    }

    // Delete image from S3 if present
    if (item.image_url) {
      await this.storageService.deleteFile(item.image_url);
    }

    // Clean up any remaining batch entries
    await this.batchModel.deleteMany({
      tenant_id: tenantId,
      item_id: itemId,
    });

    await this.itemModel.deleteOne({ tenant_id: tenantId, item_id: itemId });

    return {
      message: 'Item deleted successfully',
      item_id: itemId,
    };
  }

  async updateImage(tenantId: string, itemId: string, imageUrl: string) {
    const item = await this.itemModel.findOne({
      tenant_id: tenantId,
      item_id: itemId,
    });

    if (!item) {
      throw new NotFoundException('Item not found');
    }

    // Delete previous image from S3 if present and different
    if (item.image_url && item.image_url !== imageUrl) {
      await this.storageService.deleteFile(item.image_url);
    }

    item.image_url = imageUrl;
    await item.save();
    return item;
  }

  // --- ITEM CATEGORIES MANAGEMENT ---

  private async ensureDefaultCategories(tenantId: string): Promise<void> {
    const defaultPresets = [
      { code: 'RAW_MATERIAL', label: 'Raw Materials', is_preset: true },
      { code: 'FINISHED_GOOD', label: 'Finished Goods', is_preset: true },
      { code: 'PACKAGING', label: 'Packing Materials', is_preset: true },
    ];

    for (const preset of defaultPresets) {
      const exists = await this.itemCategoryModel.findOne({
        tenant_id: tenantId,
        code: preset.code,
      });
      if (!exists) {
        await this.itemCategoryModel.create({
          tenant_id: tenantId,
          code: preset.code,
          label: preset.label,
          is_preset: preset.is_preset,
          is_active: true,
        });
      }
    }
  }

  async getCategories(tenantId: string) {
    await this.ensureDefaultCategories(tenantId);
    return this.itemCategoryModel
      .find({ tenant_id: tenantId, is_active: true })
      .sort({ is_preset: -1, created_at: 1 });
  }

  async createCategory(tenantId: string, dto: CreateItemCategoryDto) {
    const cleanCode = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
    const cleanLabel = dto.label.trim();

    if (!cleanCode || !cleanLabel) {
      throw new BadRequestException('Category code and label are required');
    }

    const existing = await this.itemCategoryModel.findOne({
      tenant_id: tenantId,
      code: cleanCode,
    });
    if (existing) {
      if (!existing.is_active) {
        existing.is_active = true;
        existing.label = cleanLabel;
        await existing.save();
        return existing;
      }
      throw new ConflictException(`Category code "${cleanCode}" already exists`);
    }

    return this.itemCategoryModel.create({
      tenant_id: tenantId,
      code: cleanCode,
      label: cleanLabel,
      is_preset: false,
      is_active: true,
    });
  }

  async updateCategory(
    tenantId: string,
    code: string,
    dto: UpdateItemCategoryDto,
  ) {
    const cleanCode = code.trim().toUpperCase();
    const category = await this.itemCategoryModel.findOne({
      tenant_id: tenantId,
      code: cleanCode,
      is_active: true,
    });

    if (!category) {
      throw new NotFoundException('Category not found');
    }

    if (dto.label && dto.label.trim()) {
      category.label = dto.label.trim();
      await category.save();
    }

    return category;
  }

  async checkCategoryItemsCount(tenantId: string, code: string) {
    const cleanCode = code.trim().toUpperCase();
    const count = await this.itemModel.countDocuments({
      tenant_id: tenantId,
      item_type: cleanCode,
    });
    return {
      code: cleanCode,
      count,
    };
  }

  async deleteCategory(tenantId: string, code: string) {
    const cleanCode = code.trim().toUpperCase();
    const category = await this.itemCategoryModel.findOne({
      tenant_id: tenantId,
      code: cleanCode,
      is_active: true,
    });

    if (!category) {
      throw new NotFoundException('Category not found');
    }

    // Find all items in this category
    const itemsToDelete = await this.itemModel.find({
      tenant_id: tenantId,
      item_type: cleanCode,
    });

    const itemIds = itemsToDelete.map((it) => it.item_id);

    // Delete associated batches and storage room slots
    if (itemIds.length > 0) {
      await this.batchModel.deleteMany({
        tenant_id: tenantId,
        item_id: { $in: itemIds },
      });

      // Delete images if any
      for (const item of itemsToDelete) {
        if (item.image_url) {
          try {
            await this.storageService.deleteFile(item.image_url);
          } catch (_) {}
        }
      }

      // Delete the items
      await this.itemModel.deleteMany({
        tenant_id: tenantId,
        item_id: { $in: itemIds },
      });
    }

    // Delete or mark inactive category
    await this.itemCategoryModel.deleteOne({
      tenant_id: tenantId,
      code: cleanCode,
    });

    return {
      message: `Category "${category.label}" and ${itemIds.length} item(s) deleted successfully`,
      deleted_items_count: itemIds.length,
      category_code: cleanCode,
    };
  }

  // --- PACKAGING MATERIALS MANAGEMENT ---

  private async ensureDefaultPackagingMaterials(
    tenantId: string,
  ): Promise<void> {
    const defaultMaterials = [
      'Duplex',
      'Rider',
      'Pouches with rider',
      'Pouches',
      'Bucket',
      'Tub',
    ];

    for (const name of defaultMaterials) {
      const exists = await this.packagingMaterialModel.findOne({
        tenant_id: tenantId,
        name: { $regex: new RegExp(`^${name}$`, 'i') },
      });
      if (!exists) {
        await this.packagingMaterialModel.create({
          tenant_id: tenantId,
          name,
          is_preset: true,
          is_active: true,
        });
      }
    }
  }

  async getPackagingMaterials(tenantId: string) {
    await this.ensureDefaultPackagingMaterials(tenantId);
    return this.packagingMaterialModel
      .find({ tenant_id: tenantId, is_active: true })
      .sort({ is_preset: -1, created_at: 1 });
  }

  async createPackagingMaterial(
    tenantId: string,
    dto: CreatePackagingMaterialDto,
  ) {
    const cleanName = dto.name.trim();
    if (!cleanName) {
      throw new BadRequestException('Packaging material name is required');
    }

    const existing = await this.packagingMaterialModel.findOne({
      tenant_id: tenantId,
      name: { $regex: new RegExp(`^${cleanName}$`, 'i') },
    });

    if (existing) {
      if (!existing.is_active) {
        existing.is_active = true;
        existing.name = cleanName;
        await existing.save();
        return existing;
      }
      throw new ConflictException(
        `Packaging material "${cleanName}" already exists`,
      );
    }

    return this.packagingMaterialModel.create({
      tenant_id: tenantId,
      name: cleanName,
      is_preset: false,
      is_active: true,
    });
  }

  async updatePackagingMaterial(
    tenantId: string,
    idOrName: string,
    dto: UpdatePackagingMaterialDto,
  ) {
    const cleanName = dto.name?.trim();
    if (!cleanName) {
      throw new BadRequestException('New name is required');
    }

    const material = await this.packagingMaterialModel.findOne({
      tenant_id: tenantId,
      $or: [
        { material_id: idOrName },
        { name: { $regex: new RegExp(`^${idOrName}$`, 'i') } },
      ],
      is_active: true,
    });

    if (!material) {
      throw new NotFoundException('Packaging material not found');
    }

    // Rename items with this packaging material name if they are in PACKAGING category
    await this.itemModel.updateMany(
      {
        tenant_id: tenantId,
        item_type: 'PACKAGING',
        item_name: material.name,
      },
      {
        $set: { item_name: cleanName },
      },
    );

    await this.itemModel.updateMany(
      { tenant_id: tenantId, packing_material: material.name },
      { $set: { packing_material: cleanName } },
    );

    material.name = cleanName;
    await material.save();
    return material;
  }

  async checkPackagingMaterialItemsCount(tenantId: string, idOrName: string) {
    const material = await this.packagingMaterialModel.findOne({
      tenant_id: tenantId,
      $or: [
        { material_id: idOrName },
        { name: { $regex: new RegExp(`^${idOrName}$`, 'i') } },
      ],
    });

    const materialName = material ? material.name : idOrName;
    const count = await this.itemModel.countDocuments({
      tenant_id: tenantId,
      item_type: 'PACKAGING',
      item_name: { $regex: new RegExp(`^${materialName}$`, 'i') },
    });

    return {
      name: materialName,
      count,
    };
  }

  async deletePackagingMaterial(tenantId: string, idOrName: string) {
    const material = await this.packagingMaterialModel.findOne({
      tenant_id: tenantId,
      $or: [
        { material_id: idOrName },
        { name: { $regex: new RegExp(`^${idOrName}$`, 'i') } },
      ],
      is_active: true,
    });

    if (!material) {
      throw new NotFoundException('Packaging material not found');
    }

    // Find all items with this packaging material
    const itemsToDelete = await this.itemModel.find({
      tenant_id: tenantId,
      item_type: 'PACKAGING',
      item_name: { $regex: new RegExp(`^${material.name}$`, 'i') },
    });

    const itemIds = itemsToDelete.map((it) => it.item_id);

    if (itemIds.length > 0) {
      await this.batchModel.deleteMany({
        tenant_id: tenantId,
        item_id: { $in: itemIds },
      });

      for (const item of itemsToDelete) {
        if (item.image_url) {
          try {
            await this.storageService.deleteFile(item.image_url);
          } catch (_) {}
        }
      }

      await this.itemModel.deleteMany({
        tenant_id: tenantId,
        item_id: { $in: itemIds },
      });
    }

    await this.packagingMaterialModel.deleteOne({
      tenant_id: tenantId,
      material_id: material.material_id,
    });

    return {
      message: `Packaging material "${material.name}" and ${itemIds.length} item(s) deleted successfully`,
      deleted_items_count: itemIds.length,
      name: material.name,
    };
  }
}

