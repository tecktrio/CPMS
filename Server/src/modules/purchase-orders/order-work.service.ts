import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  PurchaseOrder, PurchaseOrderActivity, PurchaseOrderDocument, PurchaseOrderItem,
  PurchaseOrderStatus, releasedOrderStatuses,
} from '../../database/schemas/purchase-order.schema';
import { ProductionAssignment, ProductionAssignmentDocument } from '../../database/schemas/production-assignment.schema';
import { QcReport, QcReportDocument } from '../../database/schemas/qc-report.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { AssignmentStaffService } from '../production/assignment-staff.service';
import { PurchaseOrdersService } from './purchase-orders.service';

export const orderWorkRoles = ['PRODUCTION_MANAGER', 'SUPERVISOR', 'QC', 'PACKER', 'EXPORT', 'ACCOUNTS'] as const;
export type OrderWorkRole = (typeof orderWorkRoles)[number];

const activeStatuses = [PurchaseOrderStatus.CONFIRMED, PurchaseOrderStatus.IN_PRODUCTION];

@Injectable()
export class OrderWorkService {
  constructor(
    @InjectModel(PurchaseOrder.name) private readonly orders: Model<PurchaseOrderDocument>,
    @InjectModel(ProductionAssignment.name) private readonly assignments: Model<ProductionAssignmentDocument>,
    @InjectModel(QcReport.name) private readonly reports: Model<QcReportDocument>,
    @InjectModel(User.name) private readonly users: Model<UserDocument>,
    private readonly staff: AssignmentStaffService,
    private readonly purchases: PurchaseOrdersService,
  ) {}

  async list(tenantId: string, userId: string, role: OrderWorkRole) {
    const needsAssignments = role === 'SUPERVISOR' || role === 'PRODUCTION_MANAGER';
    const assignments = needsAssignments ? await this.assignments.find({
      tenant_id: tenantId,
      ...(role === 'SUPERVISOR'
        ? { status: { $ne: 'CANCELLED' }, supervisor_user_id: userId }
        : { $or: [
          { status: { $ne: 'CANCELLED' } },
          { 'progress_history.0': { $exists: true } },
        ] }),
    }).sort({ target_date: 1, created_at: 1 }).lean() : [];
    const byOrder = new Map<string, typeof assignments>();
    for (const assignment of assignments) {
      const group = byOrder.get(assignment.po_id) ?? [];
      group.push(assignment);
      byOrder.set(assignment.po_id, group);
    }
    const orders = await this.orders.find({
      tenant_id: tenantId,
      status: { $in: role === 'PACKER' ? activeStatuses : releasedOrderStatuses },
      ...(role === 'SUPERVISOR' && { po_id: { $in: [...byOrder.keys()] } }),
      ...(role === 'QC' && { 'items.qa_user_id': userId }),
    }).sort({ po_date: -1 }).lean();

    const qualityUserIds = role === 'PRODUCTION_MANAGER'
      ? orders.flatMap((order) => order.items.map((item) => item.qa_user_id)).filter(Boolean)
      : [];
    const qualityUsers = qualityUserIds.length ? await this.users.find({
      user_id: { $in: qualityUserIds },
    }).select('user_id full_name email_address').lean() : [];
    const qualityNames = new Map(qualityUsers.map((user) => [user.user_id, user.full_name || user.email_address]));

    return orders.map((order) => {
      const orderAssignments = byOrder.get(order.po_id) ?? [];
      const basic = {
        po_id: order.po_id,
        po_number: order.po_number,
        po_date: order.po_date,
        expected_shipping_date: order.expected_shipping_date,
        customer_name: order.customer_name,
        status: order.status,
        editable: activeStatuses.includes(order.status),
      };
      if (role === 'EXPORT') {
        const packed = order.items.reduce((sum, item) => sum + (item.packed_cartons || 0), 0);
        return { ...basic, total_cartons: order.total_cartons, packed_cartons: packed };
      }
      if (role === 'ACCOUNTS') return basic;

      const lines = order.items
        .filter((item) => role !== 'QC' || item.qa_user_id === userId)
        .filter((item) => role !== 'SUPERVISOR' ||
          orderAssignments.some((assignment) => assignment.item_id === item.item_id))
        .map((item) => {
          const line = { item_id: item.item_id, item_name: item.item_name, sku: item.sku };
          if (role === 'QC') return {
            ...line, cartons: item.cartons, target_date: item.qa_target_date,
            checked_at: item.qa_checked_at, note: item.qa_note,
          };
          if (role === 'PACKER') return { ...line, cartons: item.cartons, packed_cartons: item.packed_cartons };
          const lineAssignments = orderAssignments.filter((assignment) => assignment.item_id === item.item_id)
            .map((assignment) => ({
              assignment_id: assignment.assignment_id,
              assignee: assignment.supervisor_name,
              ...(role === 'PRODUCTION_MANAGER' && {
                assignee_id: assignment.supervisor_user_id,
                progress_history: assignment.progress_history ?? [],
              }),
              assigned_cartons: assignment.assigned_cartons,
              completed_cartons: assignment.completed_cartons,
              assigned_at: assignment.created_at,
              target_date: assignment.target_date,
              status: assignment.status,
              notes: assignment.notes,
            }));
          if (role === 'SUPERVISOR') return { ...line, assignments: lineAssignments };
          return {
            ...line, cartons: item.cartons, qa_user_id: item.qa_user_id,
            completed_cartons: item.completed_cartons,
            packed_cartons: item.packed_cartons,
            shipped_cartons: item.shipped_cartons,
            qa_assignee: qualityNames.get(item.qa_user_id || ''),
            target_date: item.qa_target_date, checked_at: item.qa_checked_at,
            qa_completion_history: item.qa_completion_history?.length
              ? item.qa_completion_history
              : item.qa_checked_at ? [{
                at: item.qa_checked_at, user_id: item.qa_user_id, note: item.qa_note ?? '',
              }] : [],
            assignments: lineAssignments,
          };
        });
      return {
        ...basic,
        ...(role === 'PRODUCTION_MANAGER' && {
          destination: order.customer_address,
        }),
        items: lines,
      };
    });
  }

  async listStaff(tenantId: string) {
    const [supervisors, quality] = await Promise.all([
      this.staff.list(tenantId, 'Supervisor'), this.staff.list(tenantId, 'QC'),
    ]);
    return { supervisors, quality };
  }

  async assignQuality(tenantId: string, actor: string, poId: string, itemId: string, userId: string, targetDate?: string) {
    const member = await this.staff.requireMember(tenantId, 'QC', userId);
    const updated = await this.orders.updateOne({
      tenant_id: tenantId, po_id: poId, status: { $in: activeStatuses },
      items: { $elemMatch: { item_id: itemId, qa_checked_at: null } },
    }, {
      $set: {
        'items.$.qa_user_id': userId,
        'items.$.qa_target_date': targetDate ? new Date(targetDate) : null,
      },
      $inc: { __v: 1 },
      $push: { activity: {
        user_id: actor, department: 'Production Manager', action: 'Assigned quality check',
        detail: `Item ${itemId} assigned to ${member.name}`, at: new Date(),
      }},
    });
    if (!updated.matchedCount) throw new NotFoundException('Open quality check item not found');
    return { success: true };
  }

  async checkQuality(tenantId: string, actor: string, poId: string, itemId: string, note = '') {
    const itemMatch = { item_id: itemId, qa_user_id: actor, qa_checked_at: null };
    const orderFilter = {
      tenant_id: tenantId, po_id: poId, status: { $in: activeStatuses },
      items: { $elemMatch: itemMatch },
    };
    const order = await this.orders.findOne(orderFilter).select('items').lean();
    const item = order?.items.find((line) => line.item_id === itemId);
    if (!item) throw new NotFoundException('Assigned quality check not found');
    const now = new Date();
    const activity: PurchaseOrderActivity = {
      user_id: actor, department: 'Quality Assurance', action: 'Marked item checked',
      detail: [item.item_name, note.trim()].filter(Boolean).join(' · '), at: now,
    };
    const completion = { at: now, user_id: actor, note: note.trim() };
    const updated = await this.orders.updateOne(orderFilter, [
      { $set: {
        items: { $map: { input: '$items', as: 'item', in: { $cond: [
          { $and: [
            { $eq: ['$$item.item_id', { $literal: itemId }] },
            { $eq: ['$$item.qa_user_id', { $literal: actor }] },
          ] },
          { $mergeObjects: ['$$item', {
            qa_checked_at: now,
            qa_note: { $literal: completion.note },
            qa_completion_history: {
              $concatArrays: [
                { $ifNull: ['$$item.qa_completion_history', []] },
                { $literal: [completion] },
              ],
            },
          }] },
          '$$item',
        ] } } },
        __v: { $add: [{ $ifNull: ['$__v', 0] }, 1] },
        activity: { $concatArrays: [{ $ifNull: ['$activity', []] }, { $literal: [activity] }] },
      }},
    ]);
    if (!updated.matchedCount) throw new NotFoundException('Assigned quality check not found');
    return { success: true };
  }

  async accountDetail(tenantId: string, poId: string) {
    const order = await this.purchases.findOnePurchaseOrder(tenantId, poId, true);
    const [assignments, reports] = await Promise.all([
      this.assignments.find({ tenant_id: tenantId, po_id: poId }).lean(),
      this.reports.find({ tenant_id: tenantId, po_id: poId }).lean(),
    ]);
    const userIds = new Set([
      ...order.activity.map((event) => event.user_id),
      ...assignments.flatMap((entry) => [entry.assigned_by_user_id, entry.supervisor_user_id]),
      ...order.items.map((item) => item.qa_user_id).filter(Boolean),
    ]);
    const users = await this.users.find({ user_id: { $in: [...userIds] } }).select('user_id full_name email_address').lean();
    const names = Object.fromEntries(users.map((user) => [user.user_id, user.full_name || user.email_address]));
    return { order, assignments, reports, names };
  }
}
