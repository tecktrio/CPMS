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

@Injectable()
export class ItemsService {
  constructor(
    @InjectModel(Item.name)
    private readonly itemModel: Model<ItemDocument>,
    @InjectModel(StoreRoom.name)
    private readonly storeRoomModel: Model<StoreRoomDocument>,
    @InjectModel(StockBatch.name)
    private readonly batchModel: Model<StockBatchDocument>,
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

    // Verify store room exists and is active
    const storeRoom = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: dto.storage_location_details.store_room_id,
      is_active: true,
    });

    if (!storeRoom) {
      throw new BadRequestException(
        'Assigned store room is invalid or inactive',
      );
    }

    const newItem = new this.itemModel({
      item_id: uuidv4(),
      tenant_id: tenantId,
      sku: skuNormalized,
      item_name: dto.item_name.trim(),
      item_type: dto.item_type,
      measurement_unit: dto.measurement_unit,
      reorder_threshold_quantity: dto.reorder_threshold_quantity,
      storage_location_details: {
        ...dto.storage_location_details,
        is_active: true,
      },
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

        const totalStock = batches.reduce(
          (sum, b) => sum + (b.available_quantity || 0),
          0,
        );

        const isBelowThreshold =
          totalStock <= item.reorder_threshold_quantity;

        const shortfall = isBelowThreshold
          ? Math.max(0, item.reorder_threshold_quantity - totalStock)
          : 0;

        return {
          ...item.toObject(),
          current_stock_quantity: totalStock,
          active_batches_count: batches.length,
          is_below_reorder_threshold: isBelowThreshold,
          reorder_shortfall_quantity: shortfall,
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

    const totalAvailableStock = batches
      .filter(
        (b) =>
          b.batch_status === BatchStatus.AVAILABLE &&
          new Date(b.expiry_date) > new Date(),
      )
      .reduce((sum, b) => sum + (b.available_quantity || 0), 0);

    const isBelowThreshold =
      totalAvailableStock <= item.reorder_threshold_quantity;

    return {
      ...item.toObject(),
      current_stock_quantity: totalAvailableStock,
      is_below_reorder_threshold: isBelowThreshold,
      reorder_shortfall_quantity: isBelowThreshold
        ? item.reorder_threshold_quantity - totalAvailableStock
        : 0,
      batches,
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
    if (dto.reorder_threshold_quantity !== undefined)
      item.reorder_threshold_quantity = dto.reorder_threshold_quantity;

    if (dto.storage_location_details) {
      if (dto.storage_location_details.store_room_id) {
        const room = await this.storeRoomModel.findOne({
          tenant_id: tenantId,
          store_room_id: dto.storage_location_details.store_room_id,
          is_active: true,
        });
        if (!room) {
          throw new BadRequestException('Assigned store room is invalid');
        }
      }
      item.storage_location_details = {
        ...item.storage_location_details,
        ...dto.storage_location_details,
      };
    }

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

    const activeStock = await this.batchModel.countDocuments({
      tenant_id: tenantId,
      item_id: itemId,
      available_quantity: { $gt: 0 },
    });

    if (activeStock > 0) {
      throw new BadRequestException(
        `Cannot remove item: There are still active stock batches for this SKU. Please dispatch all stock first.`,
      );
    }

    await this.itemModel.deleteOne({ tenant_id: tenantId, item_id: itemId });

    return {
      message: 'Item deleted successfully',
      item_id: itemId,
    };
  }
}

