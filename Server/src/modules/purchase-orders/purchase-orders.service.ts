import {
  Injectable,
  NotFoundException,
  ConflictException,
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

  async createPurchaseOrder(tenantId: string, dto: CreatePurchaseOrderDto) {
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
        packet_per_carton: perCarton,
        cartons: cartons,
        total_packets: totalPackets,
        quantity_per_packet: qtyPerPacket,
        unit: it.unit || '',
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
      status: dto.status || PurchaseOrderStatus.CONFIRMED,
      notes: dto.notes?.trim() || '',
    });

    await po.save();
    return po;
  }

  async findAllPurchaseOrders(tenantId: string) {
    return this.poModel
      .find({ tenant_id: tenantId })
      .sort({ po_date: -1, created_at: -1 });
  }

  async findOnePurchaseOrder(tenantId: string, poId: string) {
    const po = await this.poModel.findOne({
      tenant_id: tenantId,
      po_id: poId,
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
  ) {
    const po = await this.findOnePurchaseOrder(tenantId, poId);

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

        return {
          item_id: it.item_id,
          item_name: it.item_name.trim(),
          sku: it.sku.trim().toUpperCase(),
          packet_per_carton: perCarton,
          cartons: cartons,
          total_packets: totalPackets,
          quantity_per_packet: qtyPerPacket,
          unit: it.unit || '',
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

    await po.save();
    return po;
  }

  async removePurchaseOrder(tenantId: string, poId: string) {
    const po = await this.findOnePurchaseOrder(tenantId, poId);
    await this.poModel.deleteOne({ tenant_id: tenantId, po_id: poId });
    return { success: true, message: `Purchase order ${po.po_number} deleted` };
  }
}

