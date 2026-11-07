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

        const allocatedUnits = batches.reduce(
          (sum, b) => sum + (b.available_quantity || 0),
          0,
        );

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

    const allocatedUnits = batches.reduce(
      (sum, b) => sum + (b.available_quantity || 0),
      0,
    );

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

