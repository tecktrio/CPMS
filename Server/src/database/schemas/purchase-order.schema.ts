import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type PurchaseOrderDocument = PurchaseOrder & Document;

export enum PurchaseOrderStatus {
  DRAFT = 'DRAFT',
  CONFIRMED = 'CONFIRMED',
  IN_PRODUCTION = 'IN_PRODUCTION',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELLED = 'CANCELLED',
}

@Schema({ _id: false })
export class PurchaseOrderItem {
  @Prop({ type: String, required: true })
  item_id: string;

  @Prop({ type: String, required: true })
  item_name: string;

  @Prop({ type: String, required: true })
  sku: string;

  @Prop({ type: String, default: '' })
  specification: string;

  @Prop({ type: Number, required: true, min: 0 })
  packet_per_carton: number;

  @Prop({ type: Number, required: true, min: 0 })
  cartons: number;

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  total_packets: number;

  @Prop({ type: Number, default: 1, min: 0 })
  quantity_per_packet: number;

  @Prop({ type: String, default: '' })
  unit: string;
}

export const PurchaseOrderItemSchema =
  SchemaFactory.createForClass(PurchaseOrderItem);

@Schema({
  collection: 'purchase_orders',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class PurchaseOrder {
  @Prop({ type: String, default: uuidv4, unique: true })
  po_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true, uppercase: true })
  po_number: string;

  @Prop({ type: Date, required: true, default: Date.now })
  po_date: Date;

  @Prop({ type: Date, default: null })
  expected_shipping_date: Date | null;

  @Prop({ type: String, required: true })
  customer_id: string;

  @Prop({ type: String, required: true, trim: true })
  customer_name: string;

  @Prop({ type: String, default: '' })
  customer_address: string;

  @Prop({ type: String, default: '' })
  customer_contact: string;

  @Prop({ type: [PurchaseOrderItemSchema], default: [] })
  items: PurchaseOrderItem[];

  @Prop({ type: Number, required: true, default: 0 })
  total_cartons: number;

  @Prop({ type: Number, required: true, default: 0 })
  total_packets: number;

  @Prop({ type: Number, required: true, default: 0 })
  total_items_count: number;

  @Prop({
    type: String,
    enum: Object.values(PurchaseOrderStatus),
    default: PurchaseOrderStatus.CONFIRMED,
  })
  status: PurchaseOrderStatus;

  @Prop({ type: String, default: '' })
  notes: string;
}

export const PurchaseOrderSchema = SchemaFactory.createForClass(PurchaseOrder);
PurchaseOrderSchema.index({ po_id: 1 }, { unique: true });
PurchaseOrderSchema.index({ tenant_id: 1, po_number: 1 });
PurchaseOrderSchema.index({ tenant_id: 1, po_date: -1 });

