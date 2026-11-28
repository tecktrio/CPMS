import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  Customer,
  CustomerDocument,
} from '../../database/schemas/customer.schema';
import {
  PurchaseOrder,
  PurchaseOrderDocument,
  PurchaseOrderStatus,
  isItemPackingDone,
  releasedOrderStatuses,
} from '../../database/schemas/purchase-order.schema';
import {
  CreateCustomerDto,
  UpdateCustomerDto,
} from './dtos/customer.dto';
import {
  CreatePurchaseOrderDto,
  UpdatePurchaseOrderDto,
} from './dtos/purchase-order.dto';

@Injectable()
export class PurchaseOrdersService {
  constructor(
    @InjectModel(Customer.name)
    private readonly customerModel: Model<CustomerDocument>,
    @InjectModel(PurchaseOrder.name)
    private readonly poModel: Model<PurchaseOrderDocument>,
  ) {}

  // ===================== CUSTOMERS =====================

  async createCustomer(tenantId: string, dto: CreateCustomerDto) {
    const trimmedName = dto.customer_name.trim();

    const existing = await this.customerModel.findOne({
      tenant_id: tenantId,
      customer_name: new RegExp(`^${trimmedName}$`, 'i'),
    });

    if (existing) {
      if (!existing.is_active) {
        existing.is_active = true;
        if (dto.address) existing.address = dto.address.trim();
        if (dto.contact_details) existing.contact_details = dto.contact_details.trim();
        await existing.save();
        return existing;
      }
      return existing; // Idempotently return existing customer
    }

    const customer = new this.customerModel({
      customer_id: uuidv4(),
      tenant_id: tenantId,
      customer_name: trimmedName,
      address: dto.address?.trim() || '',
      contact_details: dto.contact_details?.trim() || '',
      is_active: true,
    });

    await customer.save();
    return customer;
  }

  async findAllCustomers(tenantId: string) {
    return this.customerModel
      .find({ tenant_id: tenantId, is_active: true })
      .sort({ customer_name: 1 });
  }

  async findCustomerById(tenantId: string, customerId: string) {
    const customer = await this.customerModel.findOne({
      tenant_id: tenantId,
      customer_id: customerId,
    });
    if (!customer) {
      throw new NotFoundException('Customer not found');
    }
    return customer;
  }

  async updateCustomer(
    tenantId: string,
    customerId: string,
    dto: UpdateCustomerDto,
  ) {
    const customer = await this.findCustomerById(tenantId, customerId);

    if (dto.customer_name !== undefined) {
      customer.customer_name = dto.customer_name.trim();
    }
    if (dto.address !== undefined) {
      customer.address = dto.address.trim();
    }
    if (dto.contact_details !== undefined) {
      customer.contact_details = dto.contact_details.trim();
    }
    if (dto.is_active !== undefined) {
      customer.is_active = dto.is_active;
    }

    await customer.save();
    return customer;
  }

  async deleteCustomer(tenantId: string, customerId: string) {
    const customer = await this.findCustomerById(tenantId, customerId);
    customer.is_active = false;
    await customer.save();
    return { success: true, message: 'Customer removed' };
  }

  // ===================== PURCHASE ORDERS =====================

  async createPurchaseOrder(tenantId: string, dto: CreatePurchaseOrderDto, userId: string, salesOnly = false) {
    if (salesOnly && dto.status !== undefined && dto.status !== PurchaseOrderStatus.DRAFT) {
      throw new BadRequestException('Sales must create purchase orders as drafts');
    }

    const poNum = dto.po_number.trim().toUpperCase();

    const existing = await this.poModel.findOne({
      tenant_id: tenantId,
      po_number: poNum,
    });

    if (existing) {
      throw new ConflictException(
        `Purchase Order number '${poNum}' already exists in your organization`,
      );
    }

    // Process and validate items
    const processedItems = (dto.items || []).map((it) => {
      const perCarton = Number(it.packet_per_carton) || 0;
      const cartons = Number(it.cartons) || 0;
      const totalPackets =
        it.total_packets !== undefined
          ? Number(it.total_packets)
          : perCarton * cartons;
      const qtyPerPacket =
        it.quantity_per_packet !== undefined && Number(it.quantity_per_packet) >= 0
          ? Number(it.quantity_per_packet)
          : 1;

      return {
        item_id: it.item_id,
        item_name: it.item_name.trim(),
        sku: it.sku.trim().toUpperCase(),
        specification: it.specification?.trim() || '',
        packet_per_carton: perCarton,
        cartons: cartons,
        total_packets: totalPackets,
        quantity_per_packet: qtyPerPacket,
        unit: it.unit || '',
        completed_cartons:
          it.completed_cartons !== undefined ? Number(it.completed_cartons) : 0,
        qc_passed: it.qc_passed === true,
        packed_cartons:
          it.packed_cartons !== undefined ? Number(it.packed_cartons) : 0,
        shipped_cartons:
          it.shipped_cartons !== undefined ? Number(it.shipped_cartons) : 0,
        item_status: it.item_status || 'PENDING',
      };
    });

    const totalCartons = processedItems.reduce(
      (sum, it) => sum + (it.cartons || 0),
      0,
    );
    const totalPackets = processedItems.reduce(
      (sum, it) => sum + (it.total_packets || 0),
      0,
    );

    const poDate = new Date(dto.po_date);
    const shippingDate = dto.expected_shipping_date
      ? new Date(dto.expected_shipping_date)
      : null;

    const po = new this.poModel({
      po_id: uuidv4(),
      tenant_id: tenantId,
      po_number: poNum,
      po_date: isNaN(poDate.getTime()) ? new Date() : poDate,
      expected_shipping_date: shippingDate && !isNaN(shippingDate.getTime()) ? shippingDate : null,
      customer_id: dto.customer_id,
      customer_name: dto.customer_name.trim(),
      customer_address: dto.customer_address?.trim() || '',
      customer_contact: dto.customer_contact?.trim() || '',
      items: processedItems,
      total_cartons: totalCartons,
      total_packets: totalPackets,
      total_items_count: processedItems.length,
      status: dto.status || PurchaseOrderStatus.DRAFT,
      notes: dto.notes?.trim() || '',
      activity: [{
        user_id: userId,
        department: 'Sales',
        action: 'Created purchase order',
        detail: dto.status || PurchaseOrderStatus.DRAFT,
        at: new Date(),
      }],
    });

    await po.save();
    return po;
  }

  async findAllPurchaseOrders(tenantId: string, confirmedOnly = false) {
    return this.poModel
      .find({
        tenant_id: tenantId,
        ...(confirmedOnly && { status: { $in: releasedOrderStatuses } }),
      })
      .sort({ po_date: -1, created_at: -1 });
  }

  async findOnePurchaseOrder(tenantId: string, poId: string, confirmedOnly = false) {
    const po = await this.poModel.findOne({
      tenant_id: tenantId,
      po_id: poId,
      ...(confirmedOnly && { status: { $in: releasedOrderStatuses } }),
    });
    if (!po) {
      throw new NotFoundException('Purchase Order not found');
    }
    return po;
  }

  async updatePurchaseOrder(
    tenantId: string,
    poId: string,
    dto: UpdatePurchaseOrderDto,
    userId: string,
    salesOnly = false,
  ) {
    const po = await this.findOnePurchaseOrder(tenantId, poId);

    if (salesOnly && dto.status !== undefined && dto.status !== po.status &&
        (po.status !== PurchaseOrderStatus.DRAFT || dto.status !== PurchaseOrderStatus.CONFIRMED)) {
      throw new BadRequestException('Sales can only confirm a draft purchase order');
    }

    if (dto.po_number && dto.po_number.trim().toUpperCase() !== po.po_number) {
      const normalized = dto.po_number.trim().toUpperCase();
      const existing = await this.poModel.findOne({
        tenant_id: tenantId,
        po_number: normalized,
        po_id: { $ne: poId },
      });
      if (existing) {
        throw new ConflictException(
          `Purchase Order number '${normalized}' is already in use`,
        );
      }
      po.po_number = normalized;
    }

    if (dto.po_date !== undefined) {
      const d = new Date(dto.po_date);
      if (!isNaN(d.getTime())) po.po_date = d;
    }

    if (dto.expected_shipping_date !== undefined) {
      if (dto.expected_shipping_date) {
        const d = new Date(dto.expected_shipping_date);
        po.expected_shipping_date = !isNaN(d.getTime()) ? d : null;
      } else {
        po.expected_shipping_date = null;
      }
    }

    if (dto.customer_id !== undefined) po.customer_id = dto.customer_id;
    if (dto.customer_name !== undefined) po.customer_name = dto.customer_name.trim();
    if (dto.customer_address !== undefined) po.customer_address = dto.customer_address.trim();
    if (dto.customer_contact !== undefined) po.customer_contact = dto.customer_contact.trim();
    const previousStatus = po.status;
    if (dto.status !== undefined) po.status = dto.status;
    if (dto.notes !== undefined) po.notes = dto.notes.trim();

    if (dto.items !== undefined) {
      po.items = dto.items.map((it) => {
        const perCarton = Number(it.packet_per_carton) || 0;
        const cartons = Number(it.cartons) || 0;
        const totalPackets =
          it.total_packets !== undefined
            ? Number(it.total_packets)
            : perCarton * cartons;
        const qtyPerPacket =
          it.quantity_per_packet !== undefined && Number(it.quantity_per_packet) >= 0
            ? Number(it.quantity_per_packet)
            : 1;

        const existingItem = po.items.find((p) => p.item_id === it.item_id);

        return {
          item_id: it.item_id,
          item_name: it.item_name.trim(),
          sku: it.sku.trim().toUpperCase(),
          specification: it.specification?.trim() || '',
          packet_per_carton: perCarton,
          cartons: cartons,
          total_packets: totalPackets,
          quantity_per_packet: qtyPerPacket,
          unit: it.unit || '',
          completed_cartons: existingItem?.completed_cartons || 0,
          production_done: existingItem?.production_done === true &&
            cartons > 0 && existingItem.completed_cartons >= cartons,
          qa_user_id: existingItem?.qa_user_id,
          qa_target_date: existingItem?.qa_target_date,
          qa_checked_at: existingItem?.qa_checked_at,
          qa_note: existingItem?.qa_note,
          qa_completion_history: existingItem?.qa_completion_history,
          packing_assignment: existingItem?.packing_assignment,
          export_assignment: existingItem?.export_assignment,
          qc_passed: existingItem?.qc_passed || false,
          packed_cartons: existingItem?.packed_cartons || 0,
          shipped_cartons: existingItem?.shipped_cartons || 0,
          item_status: existingItem?.item_status || 'PENDING',
        };
      });

      po.total_cartons = po.items.reduce(
        (sum, it) => sum + (it.cartons || 0),
        0,
      );
      po.total_packets = po.items.reduce(
        (sum, it) => sum + (it.total_packets || 0),
        0,
      );
      po.total_items_count = po.items.length;
    }

    po.activity.push({
      user_id: userId,
      department: 'Sales',
      action: 'Updated purchase order',
      detail: previousStatus === po.status ? '' : `${previousStatus} → ${po.status}`,
      at: new Date(),
    });
    await po.save();
    return po;
  }

  async updateItemProduction(
    tenantId: string,
    poId: string,
    itemId: string,
    completedCartons: number,
    itemStatus?: string,
    confirmedOnly = false,
  ) {
    const po = await this.findOnePurchaseOrder(tenantId, poId, confirmedOnly);
    const item = po.items.find((it) => it.item_id === itemId);
    if (!item) {
      throw new NotFoundException(
        `Item "${itemId}" not found in PO "${po.po_number}"`,
      );
    }

    if (item.production_done) {
      throw new BadRequestException('Production is already marked done for this item');
    }

    item.completed_cartons = Math.max(0, completedCartons);
    if (itemStatus) {
      item.item_status = itemStatus;
    } else {
      if (item.completed_cartons >= item.cartons) {
        item.item_status = 'PRODUCED';
      } else if (item.completed_cartons > 0) {
        item.item_status = 'IN_PRODUCTION';
      } else {
        item.item_status = 'PENDING';
      }
    }

    po.total_completed_cartons = po.items.reduce(
      (sum, it) => sum + (it.completed_cartons || 0),
      0,
    );

    // If any item is in production, transition PO status if currently CONFIRMED or DRAFT
    if (
      po.total_completed_cartons > 0 &&
      (po.status === PurchaseOrderStatus.CONFIRMED ||
        po.status === PurchaseOrderStatus.DRAFT)
    ) {
      po.status = PurchaseOrderStatus.IN_PRODUCTION;
    }

    po.markModified('items');
    await po.save();
    return { success: true, item, po };
  }

  async updateItemPacking(
    tenantId: string,
    poId: string,
    itemId: string,
    packedCartons: number,
    userId: string,
    isAdministrator = false,
    markPacked?: boolean,
  ) {
    const po = await this.findOnePurchaseOrder(tenantId, poId, true);
    const item = po.items.find((it) => it.item_id === itemId);
    if (!item) {
      throw new NotFoundException(`Item "${itemId}" not found in PO "${po.po_number}"`);
    }

    if (!isAdministrator && item.packing_assignment?.user_id !== userId) {
      throw new ForbiddenException('This item is not assigned to you for packing');
    }

    if (![PurchaseOrderStatus.CONFIRMED, PurchaseOrderStatus.IN_PRODUCTION].includes(po.status)) {
      throw new BadRequestException('This order is closed for packing');
    }
    if (!Number.isInteger(packedCartons) || packedCartons < 0 ||
        packedCartons > item.cartons || packedCartons < item.shipped_cartons) {
      throw new BadRequestException('Packed cartons must be between shipped and ordered cartons');
    }
    const finalize = markPacked ?? (item.cartons > 0 && packedCartons === item.cartons);
    if (finalize && (item.cartons <= 0 || packedCartons !== item.cartons)) {
      throw new BadRequestException('Pack all ordered cartons before marking the item packed');
    }
    const alreadyDone = isItemPackingDone(item);
    if (!isAdministrator && alreadyDone && item.packed_cartons !== packedCartons) {
      throw new BadRequestException('Packing is already marked done for this item');
    }
    if (item.packed_cartons === packedCartons && (!finalize || alreadyDone)) return { success: true };
    if (!item.qa_checked_at) {
      throw new BadRequestException('Waiting for QA to be marked done');
    }
    item.packed_cartons = packedCartons;
    if (!['PARTIALLY_SHIPPED', 'SHIPPED'].includes(item.item_status)) {
      item.item_status = finalize ? 'PACKED' : packedCartons > 0 ? 'PACKING' : 'QC_APPROVED';
    }

    po.total_packed_cartons = po.items.reduce(
      (sum, it) => sum + (it.packed_cartons || 0),
      0,
    );

    po.activity.push({
      user_id: userId, department: 'Packing', action: finalize ? 'Marked item packed' : 'Updated packed cartons',
      detail: `${item.item_name}: ${packedCartons} / ${item.cartons} cartons`, at: new Date(),
    });
    await po.save();
    return { success: true, item, po };
  }

  async updateItemShipping(
    tenantId: string,
    poId: string,
    itemId: string,
    shippedCartons: number,
    itemStatus: string | undefined,
    userId: string,
    isAdministrator = false,
  ) {
    const po = await this.findOnePurchaseOrder(tenantId, poId);
    const item = po.items.find((it) => it.item_id === itemId);
    if (!item) {
      throw new NotFoundException(`Item "${itemId}" not found in PO "${po.po_number}"`);
    }

    if (!isAdministrator) {
      if (item.export_assignment?.user_id !== userId) {
        throw new ForbiddenException('This item is not assigned to you for export');
      }
      if (item.cartons <= 0 || shippedCartons !== item.cartons ||
          !isItemPackingDone(item) ||
          (itemStatus !== undefined && itemStatus !== 'SHIPPED')) {
        throw new BadRequestException('The item must be marked packed before marking it shipped');
      }
      if (item.shipped_cartons === item.cartons && item.item_status === 'SHIPPED') {
        return { success: true, item, po };
      }
      if (![PurchaseOrderStatus.CONFIRMED, PurchaseOrderStatus.IN_PRODUCTION].includes(po.status)) {
        throw new BadRequestException('This order is closed for shipping');
      }
    }

    item.shipped_cartons = Math.max(0, shippedCartons);
    if (itemStatus) {
      item.item_status = itemStatus;
    } else {
      item.item_status =
        item.shipped_cartons >= item.cartons ? 'SHIPPED' : 'PARTIALLY_SHIPPED';
    }

    po.total_shipped_cartons = po.items.reduce(
      (sum, it) => sum + (it.shipped_cartons || 0),
      0,
    );

    // If all items are shipped, transition entire PO status to SHIPPED
    const allShipped = po.items.every(
      (it) => (it.shipped_cartons || 0) >= (it.cartons || 0) && it.cartons > 0,
    );
    if (allShipped && po.items.length > 0) {
      po.status = PurchaseOrderStatus.SHIPPED;
    }

    po.activity.push({
      user_id: userId, department: 'Export', action: 'Updated shipped cartons',
      detail: `${item.item_name}: ${shippedCartons} / ${item.cartons} cartons`, at: new Date(),
    });
    await po.save();
    return { success: true, item, po };
  }

  async removePurchaseOrder(tenantId: string, poId: string) {
    const po = await this.findOnePurchaseOrder(tenantId, poId);
    await this.poModel.deleteOne({ tenant_id: tenantId, po_id: poId });
    return { success: true, message: `Purchase order ${po.po_number} deleted` };
  }
}

