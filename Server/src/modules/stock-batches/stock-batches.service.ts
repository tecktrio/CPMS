import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  StockBatch,
  StockBatchDocument,
  BatchStatus,
} from '../../database/schemas/stock-batch.schema';
import { Item, ItemDocument } from '../../database/schemas/item.schema';
import {
  StoreRoom,
  StoreRoomDocument,
} from '../../database/schemas/store-room.schema';
import { CreateStockBatchDto } from './dtos/create-stock-batch.dto';
import { UpdateStockBatchDto } from './dtos/update-stock-batch.dto';
import { AllocateFefoDto } from './dtos/allocate-fefo.dto';
import { DeductBatchesDto } from './dtos/deduct-batches.dto';

@Injectable()
export class StockBatchesService {
  constructor(
    @InjectModel(StockBatch.name)
    private readonly batchModel: Model<StockBatchDocument>,
    @InjectModel(Item.name)
    private readonly itemModel: Model<ItemDocument>,
    @InjectModel(StoreRoom.name)
    private readonly storeRoomModel: Model<StoreRoomDocument>,
  ) {}

  async create(tenantId: string, dto: CreateStockBatchDto) {
    // 1. Verify item exists and belongs to this tenant
    const item = await this.itemModel.findOne({
      tenant_id: tenantId,
      item_id: dto.item_id,
    });
    if (!item) {
      throw new NotFoundException('Item does not exist in this tenant');
    }

    // 2. Verify store room exists, is active, and has capacity
    const storeRoom = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: dto.store_room_id,
    });
    if (!storeRoom) {
      throw new NotFoundException('Store room not found');
    }
    if (!storeRoom.is_active) {
      throw new BadRequestException('Cannot allocate stock to an inactive store room');
    }

    // 3. Enforce capacity check
    const currentBatches = await this.batchModel.find({
      tenant_id: tenantId,
      store_room_id: dto.store_room_id,
      batch_status: { $in: [BatchStatus.AVAILABLE, BatchStatus.RESERVED] },
    });
    const currentUsage = currentBatches.reduce(
      (sum, b) => sum + (b.available_quantity || 0),
      0,
    );

    if (currentUsage + dto.available_quantity > storeRoom.total_capacity_units) {
      const remainingSpace = Math.max(
        0,
        storeRoom.total_capacity_units - currentUsage,
      );
      throw new BadRequestException(
        `Store room capacity exceeded. Total capacity: ${storeRoom.total_capacity_units}, currently used: ${currentUsage}, remaining space: ${remainingSpace}. Tried to add: ${dto.available_quantity}`,
      );
    }

    const mfgDate = new Date(dto.manufacturing_date);
    const expDate = new Date(dto.expiry_date);

    if (expDate <= mfgDate) {
      throw new BadRequestException(
        'Expiry date must be after the manufacturing date',
      );
    }

    const batch = new this.batchModel({
      batch_id: uuidv4(),
      tenant_id: tenantId,
      item_id: dto.item_id,
      batch_number: dto.batch_number.trim().toUpperCase(),
      storage_location_id: dto.storage_location_id,
      store_room_id: dto.store_room_id,
      available_quantity: dto.available_quantity,
      manufacturing_date: mfgDate,
      expiry_date: expDate,
      batch_status: dto.batch_status || BatchStatus.AVAILABLE,
    });

    await batch.save();
    return batch;
  }

  async findAll(
    tenantId: string,
    filters?: {
      itemId?: string;
      storeRoomId?: string;
      status?: BatchStatus;
    },
  ) {
    const query: any = { tenant_id: tenantId };

    if (filters?.itemId) query.item_id = filters.itemId;
    if (filters?.storeRoomId) query.store_room_id = filters.storeRoomId;
    if (filters?.status) query.batch_status = filters.status;

    return this.batchModel
      .find(query)
      .sort({ expiry_date: 1, batch_number: 1 });
  }

  async findOne(tenantId: string, batchId: string) {
    const batch = await this.batchModel.findOne({
      tenant_id: tenantId,
      batch_id: batchId,
    });
    if (!batch) {
      throw new NotFoundException('Stock batch not found');
    }
    return batch;
  }

  async update(tenantId: string, batchId: string, dto: UpdateStockBatchDto) {
    const batch = await this.batchModel.findOne({
      tenant_id: tenantId,
      batch_id: batchId,
    });
    if (!batch) {
      throw new NotFoundException('Stock batch not found');
    }

    if (dto.available_quantity !== undefined) {
      batch.available_quantity = dto.available_quantity;
      if (batch.available_quantity === 0) {
        batch.batch_status = BatchStatus.DISPATCHED;
      }
    }
    if (dto.storage_location_id)
      batch.storage_location_id = dto.storage_location_id;
    if (dto.batch_status) batch.batch_status = dto.batch_status;

    await batch.save();
    return batch;
  }

  /**
   * Suggests batch allocations based on FEFO (First-Expired, First-Out).
   * Operators review and can adjust suggested quantities on mobile before confirmation (Option B).
   */
  async suggestFefoAllocation(tenantId: string, dto: AllocateFefoDto) {
    const item = await this.itemModel.findOne({
      tenant_id: tenantId,
      item_id: dto.item_id,
    });
    if (!item) {
      throw new NotFoundException('Item not found');
    }

    // Query non-expired, available batches sorted strictly by expiry date ascending
    const availableBatches = await this.batchModel
      .find({
        tenant_id: tenantId,
        item_id: dto.item_id,
        batch_status: BatchStatus.AVAILABLE,
        available_quantity: { $gt: 0 },
        expiry_date: { $gt: new Date() },
      })
      .sort({ expiry_date: 1 });

    let remainingNeeded = dto.requested_quantity;
    const suggestedAllocations: Array<{
      batch_id: string;
      batch_number: string;
      store_room_id: string;
      expiry_date: Date;
      available_in_batch: number;
      suggested_pick_quantity: number;
    }> = [];

    for (const batch of availableBatches) {
      if (remainingNeeded <= 0) break;

      const pickAmount = Math.min(remainingNeeded, batch.available_quantity);
      suggestedAllocations.push({
        batch_id: batch.batch_id,
        batch_number: batch.batch_number,
        store_room_id: batch.store_room_id,
        expiry_date: batch.expiry_date,
        available_in_batch: batch.available_quantity,
        suggested_pick_quantity: parseFloat(pickAmount.toFixed(4)),
      });

      remainingNeeded -= pickAmount;
    }

    const totalAllocated = dto.requested_quantity - Math.max(0, remainingNeeded);
    const deficit = Math.max(0, remainingNeeded);

    return {
      item_id: item.item_id,
      item_name: item.item_name,
      measurement_unit: item.measurement_unit,
      requested_quantity: dto.requested_quantity,
      allocated_quantity: parseFloat(totalAllocated.toFixed(4)),
      deficit_quantity: parseFloat(deficit.toFixed(4)),
      has_shortfall: deficit > 0,
      suggested_allocations: suggestedAllocations,
    };
  }

  /**
   * Finalizes and deducts quantities confirmed by the operator (Option B).
   */
  async deductBatches(tenantId: string, dto: DeductBatchesDto) {
    const updatedBatches: any[] = [];

    for (const item of dto.allocations) {
      const batch = await this.batchModel.findOne({
        tenant_id: tenantId,
        batch_id: item.batch_id,
      });

      if (!batch) {
        throw new NotFoundException(
          `Batch '${item.batch_id}' not found in this tenant`,
        );
      }

      if (batch.batch_status !== BatchStatus.AVAILABLE) {
        throw new BadRequestException(
          `Batch '${batch.batch_number}' is ${batch.batch_status.toLowerCase()} and cannot be deducted`,
        );
      }

      if (item.deduct_quantity > batch.available_quantity) {
        throw new BadRequestException(
          `Cannot deduct ${item.deduct_quantity} from batch '${batch.batch_number}'. Available stock is only ${batch.available_quantity}`,
        );
      }

      batch.available_quantity = parseFloat(
        (batch.available_quantity - item.deduct_quantity).toFixed(4),
      );

      if (batch.available_quantity === 0) {
        batch.batch_status = BatchStatus.DISPATCHED;
      }

      await batch.save();
      updatedBatches.push({
        batch_id: batch.batch_id,
        batch_number: batch.batch_number,
        deducted_quantity: item.deduct_quantity,
        remaining_quantity: batch.available_quantity,
        batch_status: batch.batch_status,
      });
    }

    return {
      message: 'Batches deducted successfully',
      reason: dto.reason,
      processed_batches: updatedBatches,
    };
  }

  async findExpiringSoon(tenantId: string, daysThreshold: number = 7) {
    const now = new Date();
    const thresholdDate = new Date();
    thresholdDate.setDate(now.getDate() + daysThreshold);

    return this.batchModel
      .find({
        tenant_id: tenantId,
        batch_status: BatchStatus.AVAILABLE,
        available_quantity: { $gt: 0 },
        expiry_date: { $gte: now, $lte: thresholdDate },
      })
      .sort({ expiry_date: 1 });
  }
}

