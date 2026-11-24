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

export function normalizeDivisionName(name: string): string {
  const clean = (name || '').trim();
  if (!clean) return 'Division - section 1';
  if (clean.toLowerCase().startsWith('division')) return clean;
  return `Division - ${clean}`;
}

export function normalizeDivisions(
  divisions: any[],
): { division_id: string; name: string }[] {
  if (!divisions || !Array.isArray(divisions)) return [];
  return divisions.map((d, index) => {
    if (typeof d === 'string') {
      const formatted = normalizeDivisionName(d);
      return {
        division_id: `div_${index + 1}_${formatted.toLowerCase().replace(/[^a-z0-9]/g, '_')}`,
        name: formatted,
      };
    } else if (d && typeof d === 'object') {
      const rawName = (d.name || d.division || `section ${index + 1}`).trim();
      const formatted = normalizeDivisionName(rawName);
      return {
        division_id:
          d.division_id ||
          d.divisionId ||
          `div_${index + 1}_${formatted.toLowerCase().replace(/[^a-z0-9]/g, '_')}`,
        name: formatted,
      };
    }
    return {
      division_id: `div_${index + 1}`,
      name: `Division - section ${index + 1}`,
    };
  });
}

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

    const divisions =
      dto.divisions && dto.divisions.length > 0
        ? normalizeDivisions(dto.divisions)
        : [
            { division_id: 'div_1', name: 'Division - section 1' },
            { division_id: 'div_2', name: 'Division - section 2' },
          ];

    const room = new this.storeRoomModel({
      store_room_id: uuidv4(),
      tenant_id: tenantId,
      room_code: dto.room_code.trim().toUpperCase(),
      room_name: dto.room_name.trim(),
      description: dto.description?.trim() || '',
      temperature: dto.temperature ?? null,
      total_capacity_units: dto.total_capacity_units ?? 0,
      divisions,
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

        const normDivs = normalizeDivisions(room.divisions || []);
        const mappedItems = (room.items || []).map((it) => {
          let matched = normDivs.find((d) => d.division_id === it.division_id);
          if (!matched && it.division) {
            matched = normDivs.find(
              (d) =>
                d.name.toLowerCase() === it.division.toLowerCase() ||
                d.name.toLowerCase() ===
                  normalizeDivisionName(it.division).toLowerCase(),
            );
          }
          return {
            item_id: it.item_id,
            division_id: matched
              ? matched.division_id
              : it.division_id || (normDivs.length > 0 ? normDivs[0].division_id : 'div_1'),
            division: matched
              ? matched.name
              : normalizeDivisionName(it.division),
            quantity: it.quantity,
            min_count: it.min_count,
          };
        });

        return {
          ...room.toObject(),
          divisions: normDivs,
          items: mappedItems,
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

    const normDivs = normalizeDivisions(room.divisions || []);
    const mappedItems = (room.items || []).map((it) => {
      let matched = normDivs.find((d) => d.division_id === it.division_id);
      if (!matched && it.division) {
        matched = normDivs.find(
          (d) =>
            d.name.toLowerCase() === it.division.toLowerCase() ||
            d.name.toLowerCase() ===
              normalizeDivisionName(it.division).toLowerCase(),
        );
      }
      return {
        item_id: it.item_id,
        division_id: matched
          ? matched.division_id
          : it.division_id || (normDivs.length > 0 ? normDivs[0].division_id : 'div_1'),
        division: matched
          ? matched.name
          : normalizeDivisionName(it.division),
        quantity: it.quantity,
        min_count: it.min_count,
      };
    });

    return {
      ...room.toObject(),
      divisions: normDivs,
      items: mappedItems,
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
    if (dto.description !== undefined) room.description = dto.description.trim();
    if (dto.temperature !== undefined) room.temperature = dto.temperature;
    if (dto.is_active !== undefined) room.is_active = dto.is_active;

    if (dto.divisions !== undefined) {
      const newDivs = normalizeDivisions(dto.divisions);
      room.divisions = newDivs;

      // Re-map items if division name or division_id changed
      if (room.items && room.items.length > 0) {
        room.items = room.items.map((it) => {
          let matched = newDivs.find((d) => d.division_id === it.division_id);
          if (!matched && it.division) {
            matched = newDivs.find(
              (d) =>
                d.name.toLowerCase() === it.division.toLowerCase() ||
                d.name.toLowerCase() ===
                  normalizeDivisionName(it.division).toLowerCase(),
            );
          }
          return {
            item_id: it.item_id,
            division_id: matched
              ? matched.division_id
              : it.division_id || (newDivs.length > 0 ? newDivs[0].division_id : 'div_1'),
            division: matched
              ? matched.name
              : normalizeDivisionName(it.division),
            quantity: it.quantity,
            min_count: it.min_count,
          };
        });
      }
    }

    if (dto.items !== undefined) {
      const normDivs = normalizeDivisions(room.divisions);
      room.items = dto.items.map((it) => {
        let matched = normDivs.find((d) => d.division_id === it.division_id);
        if (!matched && it.division) {
          matched = normDivs.find(
            (d) =>
              d.name.toLowerCase() === it.division.toLowerCase() ||
              d.name.toLowerCase() ===
                normalizeDivisionName(it.division).toLowerCase(),
          );
        }
        return {
          item_id: it.item_id,
          division_id: matched
            ? matched.division_id
            : it.division_id || (normDivs.length > 0 ? normDivs[0].division_id : 'div_1'),
          division: matched
            ? matched.name
            : normalizeDivisionName(it.division || 'section 1'),
          quantity: Math.max(0, it.quantity || 0),
          min_count: Math.max(0, it.min_count || 0),
        };
      });
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
    divisionId?: string,
  ) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });
    if (!room) throw new NotFoundException('Store room not found');

    const divisions = normalizeDivisions(room.divisions);
    let matchedDiv = divisions.find((d) => d.division_id === divisionId);
    if (!matchedDiv && division) {
      matchedDiv = divisions.find(
        (d) =>
          d.name.toLowerCase() === division.trim().toLowerCase() ||
          d.name.toLowerCase() === normalizeDivisionName(division).toLowerCase(),
      );
    }
    if (!matchedDiv && divisions.length > 0) {
      matchedDiv = divisions[0];
    }

    const targetDivId = matchedDiv
      ? matchedDiv.division_id
      : divisionId || 'div_1';
    const targetDivision = matchedDiv
      ? matchedDiv.name
      : normalizeDivisionName(division || 'section 1');
    const targetQty = Math.max(0, quantity ?? 0);

    const existingIdx = room.items.findIndex(
      (it) =>
        it.item_id === itemId &&
        (it.division_id === targetDivId || it.division === targetDivision),
    );

    if (existingIdx !== -1) {
      room.items[existingIdx].quantity += targetQty;
      room.items[existingIdx].division_id = targetDivId;
      room.items[existingIdx].division = targetDivision;
    } else {
      room.items.push({
        item_id: itemId,
        division_id: targetDivId,
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
    divisionId?: string,
  ) {
    const room = await this.storeRoomModel.findOne({
      tenant_id: tenantId,
      store_room_id: storeRoomId,
    });
    if (!room) throw new NotFoundException('Store room not found');

    const divisions = normalizeDivisions(room.divisions);
    let matchedDiv = divisions.find((d) => d.division_id === divisionId);
    if (!matchedDiv && division) {
      matchedDiv = divisions.find(
        (d) =>
          d.name.toLowerCase() === division.trim().toLowerCase() ||
          d.name.toLowerCase() === normalizeDivisionName(division).toLowerCase(),
      );
    }

    const targetDivId = matchedDiv ? matchedDiv.division_id : divisionId;
    const targetDivision = matchedDiv
      ? matchedDiv.name
      : division
        ? normalizeDivisionName(division)
        : undefined;

    const matchIdx = room.items.findIndex((it) => {
      if (divisionId && it.division_id) {
        return it.item_id === itemId && it.division_id === divisionId;
      }
      if (division) {
        return it.item_id === itemId && it.division === division;
      }
      return it.item_id === itemId;
    });

    if (matchIdx === -1) {
      room.items.push({
        item_id: itemId,
        division_id:
          targetDivId ||
          (divisions.length > 0 ? divisions[0].division_id : 'div_1'),
        division:
          targetDivision ||
          (divisions.length > 0
            ? divisions[0].name
            : 'Division - section 1'),
        quantity: Math.max(0, quantity),
        min_count: Math.max(0, minCount ?? 0),
      });
    } else {
      room.items[matchIdx].quantity = Math.max(0, quantity);
      if (minCount !== undefined) {
        room.items[matchIdx].min_count = Math.max(0, minCount);
      }
      if (targetDivision) {
        room.items[matchIdx].division = targetDivision;
      }
      if (targetDivId) {
        room.items[matchIdx].division_id = targetDivId;
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

