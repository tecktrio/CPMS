import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  StoreRoom,
  StoreRoomDocument,
} from '../../database/schemas/store-room.schema';
import {
  StockBatch,
  StockBatchDocument,
  BatchStatus,
} from '../../database/schemas/stock-batch.schema';
import { CreateStoreRoomDto } from './dtos/create-store-room.dto';
import { UpdateStoreRoomDto } from './dtos/update-store-room.dto';

@Injectable()
export class StoreRoomsService {
  constructor(
    @InjectModel(StoreRoom.name)
    private readonly storeRoomModel: Model<StoreRoomDocument>,
    @InjectModel(StockBatch.name)
    private readonly batchModel: Model<StockBatchDocument>,
  ) {}

  async create(tenantId: string, dto: CreateStoreRoomDto) {
    const existing = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      room_code: dto.room_code.trim().toUpperCase(),
    });

    if (existing) {
      throw new ConflictException(
        `A store room with code '${dto.room_code}' already exists in this tenant`,
      );
    }

    const room = new this.storeRoomModel({
      store_room_id: uuidv4(),
      tenant_id: tenantId,
      room_code: dto.room_code.trim().toUpperCase(),
      room_name: dto.room_name.trim(),
      temperature: dto.temperature ?? null,
      total_capacity_units: dto.total_capacity_units,
      divisions: dto.divisions || [],
      is_active: dto.is_active ?? true,
    });

    await room.save();
    return room;
  }

  async findAll(tenantId: string) {
    const rooms = await this.storeRoomModel
      .find({ tenant_id: tenantId })
      .sort({ room_code: 1 });

    // Calculate current allocated quantity for each cold room
    const results = await Promise.all(
      rooms.map(async (room) => {
        const batches = await this.batchModel.find({
          tenant_id: tenantId,
          store_room_id: room.store_room_id,
          batch_status: { $in: [BatchStatus.AVAILABLE, BatchStatus.RESERVED] },
        });

        const batchUnits = batches.reduce(
          (sum, b) => sum + (b.available_quantity || 0),
          0,
        );
        const itemUnits = (room.items || []).reduce(
          (sum, it) => sum + (it.quantity || 0),
          0,
        );
        const allocatedUnits = Math.max(batchUnits, itemUnits);

        return {
          ...room.toObject(),
          allocated_units: allocatedUnits,
          available_capacity_units: Math.max(
            0,
            room.total_capacity_units - allocatedUnits,
          ),
          utilization_percentage:
            room.total_capacity_units > 0
              ? Math.min(
                  100,
                  parseFloat(
                    ((allocatedUnits / room.total_capacity_units) * 100).toFixed(
                      1,
                    ),
                  ),
                )
              : 0,
        };
      }),
    );

    return results;
  }

  async findOne(tenantId: string, storeRoomId: string) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });

    if (!room) {
      throw new NotFoundException('Store room not found');
    }

    const batches = await this.batchModel.find({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
      batch_status: { $in: [BatchStatus.AVAILABLE, BatchStatus.RESERVED] },
    });

    const batchUnits = batches.reduce(
      (sum, b) => sum + (b.available_quantity || 0),
      0,
    );
    const itemUnits = (room.items || []).reduce(
      (sum, it) => sum + (it.quantity || 0),
      0,
    );
    const allocatedUnits = Math.max(batchUnits, itemUnits);

    return {
      ...room.toObject(),
      allocated_units: allocatedUnits,
      available_capacity_units: Math.max(
        0,
        room.total_capacity_units - allocatedUnits,
      ),
      active_batches_count: batches.length,
    };
  }

  async update(tenantId: string, storeRoomId: string, dto: UpdateStoreRoomDto) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });

    if (!room) {
      throw new NotFoundException('Store room not found');
    }

    if (dto.room_code && dto.room_code !== room.room_code) {
      const codeExists = await this.storeRoomModel.findOne({
        tenant_id: tenantId,
        room_code: dto.room_code.trim().toUpperCase(),
        store_room_id: { $ne: storeRoomId },
      });
      if (codeExists) {
        throw new ConflictException(
          `Store room with code '${dto.room_code}' already exists`,
        );
      }
      room.room_code = dto.room_code.trim().toUpperCase();
    }

    if (dto.total_capacity_units !== undefined) {
      // Check current allocations to prevent capacity underflow
      const batches = await this.batchModel.find({
        tenant_id: tenantId,
        store_room_id: storeRoomId,
        batch_status: { $in: [BatchStatus.AVAILABLE, BatchStatus.RESERVED] },
      });
      const currentUsage = batches.reduce(
        (sum, b) => sum + (b.available_quantity || 0),
        0,
      );

      if (dto.total_capacity_units < currentUsage) {
        throw new BadRequestException(
          `Cannot reduce capacity to ${dto.total_capacity_units}. Current stock stored is ${currentUsage} units.`,
        );
      }
      room.total_capacity_units = dto.total_capacity_units;
    }

    if (dto.room_name !== undefined) room.room_name = dto.room_name.trim();
    if (dto.temperature !== undefined) room.temperature = dto.temperature;
    if (dto.divisions !== undefined) room.divisions = dto.divisions;
    if (dto.is_active !== undefined) room.is_active = dto.is_active;

    if (dto.items !== undefined) {
      room.items = dto.items.map((it) => ({
        item_id: it.item_id,
        division: it.division || 'Default Section',
        quantity: Math.max(0, it.quantity || 0),
        min_count: Math.max(0, it.min_count || 0),
      }));
      room.item_ids = Array.from(new Set(room.items.map((it) => it.item_id)));
    } else if (dto.item_ids !== undefined) {
      room.item_ids = dto.item_ids;
    }

    await room.save();
    return room;
  }

  async addItem(
    tenantId: string,
    storeRoomId: string,
    itemId: string,
    division?: string,
    quantity?: number,
    minCount?: number,
  ) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });
    if (!room) throw new NotFoundException('Store room not found');

    const targetDivision = division?.trim() || (room.divisions.length > 0 ? room.divisions[0] : 'Default Section');
    const targetQty = Math.max(0, quantity ?? 0);

    const existingIdx = room.items.findIndex(
      (it) => it.item_id === itemId && it.division === targetDivision,
    );

    if (existingIdx !== -1) {
      room.items[existingIdx].quantity += targetQty;
    } else {
      room.items.push({
        item_id: itemId,
        division: targetDivision,
        quantity: targetQty,
        min_count: Math.max(0, minCount ?? 0),
      });
    }

    room.item_ids = Array.from(new Set(room.items.map((it) => it.item_id)));
    await room.save();
    return room;
  }

  async updateItemQuantity(
    tenantId: string,
    storeRoomId: string,
    itemId: string,
    quantity: number,
    division?: string,
    minCount?: number,
  ) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });
    if (!room) throw new NotFoundException('Store room not found');

    const matchIdx = room.items.findIndex((it) => {
      if (division) {
        return it.item_id === itemId && it.division === division;
      }
      return it.item_id === itemId;
    });

    if (matchIdx === -1) {
      room.items.push({
        item_id: itemId,
        division: division?.trim() || (room.divisions.length > 0 ? room.divisions[0] : 'Default Section'),
        quantity: Math.max(0, quantity),
        min_count: Math.max(0, minCount ?? 0),
      });
    } else {
      room.items[matchIdx].quantity = Math.max(0, quantity);
      if (minCount !== undefined) {
        room.items[matchIdx].min_count = Math.max(0, minCount);
      }
      if (division) {
        room.items[matchIdx].division = division.trim();
      }
    }

    room.item_ids = Array.from(new Set(room.items.map((it) => it.item_id)));
    await room.save();
    return room;
  }

  async removeItem(tenantId: string, storeRoomId: string, itemId: string) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });
    if (!room) throw new NotFoundException('Store room not found');

    room.items = room.items.filter((it) => it.item_id !== itemId);
    room.item_ids = Array.from(new Set(room.items.map((it) => it.item_id)));
    await room.save();
    return room;
  }

  async remove(tenantId: string, storeRoomId: string) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });

    if (!room) {
      throw new NotFoundException('Store room not found');
    }

    // Verify no active batches stored before deleting
    const activeBatches = await this.batchModel.countDocuments({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
      batch_status: { $in: [BatchStatus.AVAILABLE, BatchStatus.RESERVED] },
    });

    if (activeBatches > 0) {
      throw new BadRequestException(
        `Cannot delete store room: ${activeBatches} active inventory batches are currently stored inside. Please dispatch or relocate them first.`,
      );
    }

    room.is_active = false;
    await room.save();

    return {
      message: 'Store room deactivated successfully',
      store_room_id: storeRoomId,
    };
  }
}

