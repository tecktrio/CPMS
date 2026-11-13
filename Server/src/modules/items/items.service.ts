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
        `An item with SKU '${skuNormalized}' already exists in your organization`,
      );
    }

    const newItem = new this.itemModel({
      item_id: uuidv4(),
      tenant_id: tenantId,
      sku: skuNormalized,
      item_name: dto.item_name.trim(),
      item_type: dto.item_type,
      measurement_unit: dto.measurement_unit,
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

        const totalStock = roomStock > 0 ? roomStock : batchStock;

        const isBelowThreshold =
          totalStock <= item.reorder_threshold_quantity;

        const shortfall = isBelowThreshold
          ? Math.max(0, item.reorder_threshold_quantity - totalStock)
          : 0;

        return {
          ...item.toObject(),
          total_available_stock: totalStock,
          current_stock_quantity: totalStock,
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

    const totalAvailableStock = roomStock > 0 ? roomStock : totalBatchStock;

    const isBelowThreshold =
      totalAvailableStock <= item.reorder_threshold_quantity;

    return {
      ...item.toObject(),
      total_available_stock: totalAvailableStock,
      current_stock_quantity: totalAvailableStock,
      is_below_reorder_threshold: isBelowThreshold,
      reorder_shortfall_quantity: isBelowThreshold
        ? item.reorder_threshold_quantity - totalAvailableStock
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
          `Item with SKU '${skuNormalized}' already exists`,
        );
      }
      item.sku = skuNormalized;
    }

    if (dto.item_name !== undefined) item.item_name = dto.item_name.trim();
    if (dto.item_type !== undefined) item.item_type = dto.item_type;
    if (dto.measurement_unit !== undefined)
      item.measurement_unit = dto.measurement_unit;
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
}

