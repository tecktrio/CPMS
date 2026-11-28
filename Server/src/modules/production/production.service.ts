import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Error as MongooseError, Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  ProductionAssignment,
  ProductionAssignmentDocument,
} from '../../database/schemas/production-assignment.schema';
import {
  PurchaseOrder,
  PurchaseOrderDocument,
  PurchaseOrderStatus,
  PurchaseOrderActivity,
} from '../../database/schemas/purchase-order.schema';
import { AssignmentStaffService } from './assignment-staff.service';
import {
  CreateProductionAssignmentDto,
  UpdateAssignmentDto,
  UpdateProgressDto,
} from './dtos/production-assignment.dto';

@Injectable()
export class ProductionService {
  constructor(
    @InjectModel(ProductionAssignment.name)
    private readonly assignmentModel: Model<ProductionAssignmentDocument>,
    @InjectModel(PurchaseOrder.name)
    private readonly poModel: Model<PurchaseOrderDocument>,
    private readonly staff: AssignmentStaffService,
  ) {}

  async createAssignment(
    tenantId: string,
    assignedByUserId: string,
    dto: CreateProductionAssignmentDto,
  ) {
    const po = await this.poModel.findOne({
      tenant_id: tenantId,
      po_id: dto.po_id,
      status: { $in: [PurchaseOrderStatus.CONFIRMED, PurchaseOrderStatus.IN_PRODUCTION] },
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

    const supervisor = await this.staff.requireMember(tenantId, 'Supervisor', dto.supervisor_user_id);

    // Enforce max cartons = remaining balance on this PO item
    const existingForItem = await this.assignmentModel.find({
      tenant_id: tenantId,
      po_id: po.po_id,
      item_id: item.item_id,
      status: { $ne: 'CANCELLED' },
    });
    const alreadyAssigned = existingForItem.reduce(
      (sum, a) => sum + (a.assigned_cartons || 0),
      0,
    );
    const remainingBalance = Math.max(0, item.cartons - alreadyAssigned);
    if (dto.assigned_cartons > remainingBalance) {
      throw new BadRequestException(
        `Assigned cartons (${dto.assigned_cartons}) cannot exceed remaining balance (${remainingBalance} ctns) for "${item.item_name}"`,
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
      supervisor_name: supervisor.name,
      assigned_cartons: dto.assigned_cartons,
      completed_cartons: 0,
      status: 'PENDING',
      assigned_by_user_id: assignedByUserId || supervisor.user_id,
      notes: dto.notes?.trim() || '',
      target_date: dto.target_date ? new Date(dto.target_date) : null,
    });

    await newAssignment.save();

    // Recalculate PO total assigned cartons
    await this.recalculatePoTotals(tenantId, po.po_id, {
      user_id: assignedByUserId, department: 'Production Manager', action: 'Assigned supervisor',
      detail: `${item.item_name}: ${dto.assigned_cartons} cartons assigned to ${supervisor.name}`,
      at: new Date(),
    });

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
      supervisor_user_id: requestingUserId,
      status: { $ne: 'CANCELLED' },
    });

    if (!assignment) {
      throw new NotFoundException('Production assignment not found');
    }

    const order = await this.poModel.exists({
      tenant_id: tenantId,
      po_id: assignment.po_id,
      status: { $in: [PurchaseOrderStatus.CONFIRMED, PurchaseOrderStatus.IN_PRODUCTION] },
      'items.item_id': assignment.item_id,
    });
    if (!order) throw new NotFoundException('Active purchase order item not found');

    if (dto.completed_cartons > assignment.assigned_cartons) {
      throw new BadRequestException(
        `Completed cartons (${dto.completed_cartons}) cannot exceed assigned cartons (${assignment.assigned_cartons})`,
      );
    }

    const previousCartons = assignment.completed_cartons;
    const changed = previousCartons !== dto.completed_cartons;
    const now = new Date();
    if (changed) {
      assignment.completed_cartons = dto.completed_cartons;
      if (dto.completed_cartons === 0) {
        assignment.status = 'PENDING';
        assignment.completed_at = null;
      } else if (dto.completed_cartons >= assignment.assigned_cartons) {
        assignment.status = 'COMPLETED';
        assignment.completed_at = now;
      } else {
        assignment.status = 'IN_PROGRESS';
        assignment.completed_at = null;
      }
      assignment.progress_history.push({
        at: now,
        user_id: requestingUserId,
        supervisor_name: assignment.supervisor_name,
        previous_cartons: previousCartons,
        completed_cartons: dto.completed_cartons,
      });
      await assignment.save();
    }

    // Roll up to PO line item and PO totals
    await this.recalculatePoTotals(tenantId, assignment.po_id, changed ? {
      user_id: requestingUserId,
      department: 'Supervisor',
      action: 'Updated production progress',
      detail: `${assignment.item_name}: ${dto.completed_cartons} / ${assignment.assigned_cartons} cartons`,
      at: now,
    } : undefined);

    return assignment;
  }

  async updateAssignment(
    tenantId: string,
    assignmentId: string,
    dto: UpdateAssignmentDto,
    actor: string,
  ) {
    const assignment = await this.assignmentModel.findOne({
      tenant_id: tenantId,
      assignment_id: assignmentId,
      status: { $ne: 'CANCELLED' },
    });

    if (!assignment) {
      throw new NotFoundException('Production assignment not found');
    }

    const activeOrder = await this.poModel.exists({
      tenant_id: tenantId,
      po_id: assignment.po_id,
      status: { $in: [PurchaseOrderStatus.CONFIRMED, PurchaseOrderStatus.IN_PRODUCTION] },
      'items.item_id': assignment.item_id,
    });
    if (!activeOrder) throw new NotFoundException('Active purchase order item not found');

    if (dto.supervisor_user_id && dto.supervisor_user_id !== assignment.supervisor_user_id) {
      if (assignment.completed_cartons > 0) {
        throw new BadRequestException('An assignment with recorded production cannot be reassigned.');
      }
      const supervisor = await this.staff.requireMember(tenantId, 'Supervisor', dto.supervisor_user_id);
      assignment.supervisor_user_id = supervisor.user_id;
      assignment.supervisor_name = supervisor.name;
    }

    if (dto.assigned_cartons !== undefined) {
      if (dto.assigned_cartons < assignment.completed_cartons) {
        throw new BadRequestException(
          `Assigned cartons (${dto.assigned_cartons}) cannot be less than already completed cartons (${assignment.completed_cartons})`,
        );
      }

      // Check against PO item remaining balance (excluding this assignment's previous qty)
      const po = await this.poModel.findOne({
        tenant_id: tenantId,
        po_id: assignment.po_id,
      });
      const item = po?.items.find((it) => it.item_id === assignment.item_id);
      if (item) {
        const otherAssignments = await this.assignmentModel.find({
          tenant_id: tenantId,
          po_id: assignment.po_id,
          item_id: assignment.item_id,
          assignment_id: { $ne: assignment.assignment_id },
          status: { $ne: 'CANCELLED' },
        });
        const otherAssigned = otherAssignments.reduce(
          (sum, a) => sum + (a.assigned_cartons || 0),
          0,
        );
        const maxAllowed = Math.max(0, item.cartons - otherAssigned);
        if (dto.assigned_cartons > maxAllowed) {
          throw new BadRequestException(
            `Assigned cartons (${dto.assigned_cartons}) cannot exceed remaining PO balance (${maxAllowed} ctns)`,
          );
        }
      }

      assignment.assigned_cartons = dto.assigned_cartons;
      if (assignment.completed_cartons === 0) {
        assignment.status = 'PENDING';
        assignment.completed_at = null;
      } else if (assignment.completed_cartons >= assignment.assigned_cartons) {
        assignment.status = 'COMPLETED';
        assignment.completed_at = new Date();
      } else {
        assignment.status = 'IN_PROGRESS';
        assignment.completed_at = null;
      }
    }

    if (dto.notes !== undefined) {
      assignment.notes = dto.notes.trim();
    }

    if (dto.target_date !== undefined) {
      assignment.target_date = dto.target_date ? new Date(dto.target_date) : null;
    }

    await assignment.save();
    await this.recalculatePoTotals(tenantId, assignment.po_id, {
      user_id: actor, department: 'Production Manager', action: 'Updated production assignment',
      detail: `${assignment.item_name}: ${assignment.assigned_cartons} cartons assigned to ${assignment.supervisor_name}`,
      at: new Date(),
    });

    return assignment;
  }

  async cancelAssignment(tenantId: string, assignmentId: string, actor: string) {
    const assignment = await this.assignmentModel.findOne({
      tenant_id: tenantId,
      assignment_id: assignmentId,
      status: { $ne: 'CANCELLED' },
    });

    if (!assignment) {
      throw new NotFoundException('Production assignment not found');
    }

    if (assignment.completed_cartons > 0) {
      throw new BadRequestException('An assignment with recorded production cannot be cancelled.');
    }
    assignment.status = 'CANCELLED';
    await assignment.save();

    await this.recalculatePoTotals(tenantId, assignment.po_id, {
      user_id: actor, department: 'Production Manager', action: 'Cancelled production assignment',
      detail: `${assignment.item_name}: ${assignment.supervisor_name}`, at: new Date(),
    });

    return { message: 'Assignment cancelled successfully', assignment_id: assignmentId };
  }

  private async recalculatePoTotals(tenantId: string, poId: string, activity?: PurchaseOrderActivity) {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        await this.savePoTotals(tenantId, poId, activity);
        return;
      } catch (error) {
        if (!(error instanceof MongooseError.VersionError) || attempt === 2) throw error;
      }
    }
  }

  private async savePoTotals(tenantId: string, poId: string, activity?: PurchaseOrderActivity) {
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
      if (['PENDING', 'IN_PRODUCTION', 'PRODUCED'].includes(it.item_status)) {
        if (it.completed_cartons === 0) it.item_status = 'PENDING';
        else if (it.completed_cartons >= it.cartons) it.item_status = 'PRODUCED';
        else it.item_status = 'IN_PRODUCTION';
      }
    }

    if (totalCompleted > 0 && po.status === PurchaseOrderStatus.CONFIRMED) {
      po.status = PurchaseOrderStatus.IN_PRODUCTION;
    }
    if (activity) po.activity.push(activity);
    po.markModified('items');
    await po.save();
  }
}

