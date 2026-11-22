import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  ProductionAssignment,
  ProductionAssignmentDocument,
} from '../../database/schemas/production-assignment.schema';
import {
  PurchaseOrder,
  PurchaseOrderDocument,
} from '../../database/schemas/purchase-order.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import {
  CreateProductionAssignmentDto,
  UpdateProgressDto,
} from './dtos/production-assignment.dto';

@Injectable()
export class ProductionService {
  constructor(
    @InjectModel(ProductionAssignment.name)
    private readonly assignmentModel: Model<ProductionAssignmentDocument>,
    @InjectModel(PurchaseOrder.name)
    private readonly poModel: Model<PurchaseOrderDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
  ) {}

  async createAssignment(
    tenantId: string,
    assignedByUserId: string,
    dto: CreateProductionAssignmentDto,
  ) {
    const po = await this.poModel.findOne({
      tenant_id: tenantId,
      po_id: dto.po_id,
    });
    if (!po) {
      throw new NotFoundException(`Purchase Order "${dto.po_id}" not found`);
    }

    const item = po.items.find((it) => it.item_id === dto.item_id);
    if (!item) {
      throw new NotFoundException(
        `Item "${dto.item_id}" not found in Purchase Order "${po.po_number}"`,
      );
    }

    const supervisor = await this.userModel.findOne({
      user_id: dto.supervisor_user_id,
    });
    if (!supervisor) {
      throw new NotFoundException(
        `Supervisor user "${dto.supervisor_user_id}" not found`,
      );
    }

    const newAssignment = new this.assignmentModel({
      assignment_id: uuidv4(),
      tenant_id: tenantId,
      po_id: po.po_id,
      po_number: po.po_number,
      po_item_id: item.item_id,
      item_id: item.item_id,
      item_name: item.item_name,
      supervisor_user_id: supervisor.user_id,
      supervisor_name: supervisor.full_name || supervisor.email_address,
      assigned_cartons: dto.assigned_cartons,
      completed_cartons: 0,
      status: 'PENDING',
      assigned_by_user_id: assignedByUserId || supervisor.user_id,
      notes: dto.notes?.trim() || '',
    });

    await newAssignment.save();

    // Recalculate PO total assigned cartons
    await this.recalculatePoTotals(tenantId, po.po_id);

    return newAssignment;
  }

  async getMyAssignments(tenantId: string, supervisorUserId: string) {
    return this.assignmentModel
      .find({
        tenant_id: tenantId,
        supervisor_user_id: supervisorUserId,
        status: { $ne: 'CANCELLED' },
      })
      .sort({ created_at: -1 });
  }

  async getAssignmentsByPo(tenantId: string, poId: string) {
    return this.assignmentModel
      .find({
        tenant_id: tenantId,
        po_id: poId,
        status: { $ne: 'CANCELLED' },
      })
      .sort({ item_name: 1, created_at: -1 });
  }

  async getAllAssignments(tenantId: string) {
    return this.assignmentModel
      .find({
        tenant_id: tenantId,
        status: { $ne: 'CANCELLED' },
      })
      .sort({ created_at: -1 });
  }

  async updateProgress(
    tenantId: string,
    assignmentId: string,
    requestingUserId: string,
    dto: UpdateProgressDto,
  ) {
    const assignment = await this.assignmentModel.findOne({
      tenant_id: tenantId,
      assignment_id: assignmentId,
    });

    if (!assignment) {
      throw new NotFoundException('Production assignment not found');
    }

    if (
      assignment.supervisor_user_id !== requestingUserId &&
      assignment.assigned_by_user_id !== requestingUserId
    ) {
      // Checked in permissions guard, but ensure user can only modify their own if they are supervisor
    }

    if (dto.completed_cartons > assignment.assigned_cartons) {
      throw new BadRequestException(
        `Completed cartons (${dto.completed_cartons}) cannot exceed assigned cartons (${assignment.assigned_cartons})`,
      );
    }

    assignment.completed_cartons = dto.completed_cartons;
    if (dto.completed_cartons === 0) {
      assignment.status = 'PENDING';
      assignment.completed_at = null;
    } else if (dto.completed_cartons >= assignment.assigned_cartons) {
      assignment.status = 'COMPLETED';
      assignment.completed_at = new Date();
    } else {
      assignment.status = 'IN_PROGRESS';
      assignment.completed_at = null;
    }

    await assignment.save();

    // Roll up to PO line item and PO totals
    await this.recalculatePoTotals(tenantId, assignment.po_id);

    return assignment;
  }

  async cancelAssignment(tenantId: string, assignmentId: string) {
    const assignment = await this.assignmentModel.findOne({
      tenant_id: tenantId,
      assignment_id: assignmentId,
    });

    if (!assignment) {
      throw new NotFoundException('Production assignment not found');
    }

    assignment.status = 'CANCELLED';
    await assignment.save();

    await this.recalculatePoTotals(tenantId, assignment.po_id);

    return { message: 'Assignment cancelled successfully', assignment_id: assignmentId };
  }

  private async recalculatePoTotals(tenantId: string, poId: string) {
    const po = await this.poModel.findOne({ tenant_id: tenantId, po_id: poId });
    if (!po) return;

    const activeAssignments = await this.assignmentModel.find({
      tenant_id: tenantId,
      po_id: poId,
      status: { $ne: 'CANCELLED' },
    });

    let totalAssigned = 0;
    let totalCompleted = 0;

    // Map item completions
    const itemCompletions = new Map<string, number>();
    for (const a of activeAssignments) {
      totalAssigned += a.assigned_cartons || 0;
      totalCompleted += a.completed_cartons || 0;
      const cur = itemCompletions.get(a.item_id) || 0;
      itemCompletions.set(a.item_id, cur + (a.completed_cartons || 0));
    }

    po.total_assigned_cartons = totalAssigned;
    po.total_completed_cartons = totalCompleted;

    for (const it of po.items) {
      it.completed_cartons = itemCompletions.get(it.item_id) || 0;
      if (it.completed_cartons > 0 && it.item_status === 'PENDING') {
        it.item_status =
          it.completed_cartons >= it.cartons ? 'PRODUCED' : 'IN_PRODUCTION';
      }
    }

    po.markModified('items');
    await po.save();
  }
}

