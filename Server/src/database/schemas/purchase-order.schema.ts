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

export const releasedOrderStatuses = [
  PurchaseOrderStatus.CONFIRMED,
  PurchaseOrderStatus.IN_PRODUCTION,
  PurchaseOrderStatus.SHIPPED,
  PurchaseOrderStatus.DELIVERED,
];

@Schema({ _id: false })
export class PurchaseOrderActivity {
  @Prop({ type: String, required: true })
  user_id: string;

  @Prop({ type: String, required: true })
  department: string;

  @Prop({ type: String, required: true })
  action: string;

  @Prop({ type: Date, default: Date.now })
  at: Date;

  @Prop({ type: String, default: '' })
  detail: string;
}

@Schema({ _id: false })
export class QualityCompletionEntry {
  @Prop({ type: Date, required: true })
  at: Date;

  @Prop({ type: String, required: true })
  user_id: string;

  @Prop({ type: String, default: '' })
  note: string;
}

@Schema({ _id: false })
export class ItemDepartmentAssignment {
  @Prop({ type: String, required: true })
  user_id: string;

  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: Date, required: true })
  assigned_at: Date;
}

const ItemDepartmentAssignmentSchema = SchemaFactory.createForClass(ItemDepartmentAssignment);

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

  @Prop({ type: String, default: '' })
  qa_user_id?: string;

  @Prop({ type: Date, default: null })
  qa_target_date?: Date | null;

  @Prop({ type: Date, default: null })
  qa_checked_at?: Date | null;

  @Prop({ type: String, default: '' })
  qa_note?: string;

  @Prop({ type: [SchemaFactory.createForClass(QualityCompletionEntry)], default: [] })
  qa_completion_history?: QualityCompletionEntry[];

  @Prop({ type: ItemDepartmentAssignmentSchema, default: null })
  packing_assignment?: ItemDepartmentAssignment | null;

  @Prop({ type: ItemDepartmentAssignmentSchema, default: null })
  export_assignment?: ItemDepartmentAssignment | null;

  @Prop({ type: Boolean, default: false })
  production_done?: boolean;

  // Lifecycle Stage Quantities per Line Item:
  @Prop({ type: Number, default: 0, min: 0 })
  completed_cartons: number;

  @Prop({ type: Boolean, default: false })
  qc_passed: boolean;

  @Prop({ type: Number, default: 0, min: 0 })
  packed_cartons: number;

  @Prop({ type: Number, default: 0, min: 0 })
  shipped_cartons: number;

  @Prop({
    type: String,
    enum: [
      'PENDING',
      'IN_PRODUCTION',
      'PRODUCED',
      'QC_APPROVED',
      'PACKING',
      'PACKED',
      'PARTIALLY_SHIPPED',
      'SHIPPED',
    ],
    default: 'PENDING',
  })
  item_status: string;
}

export const PurchaseOrderItemSchema =
  SchemaFactory.createForClass(PurchaseOrderItem);

@Schema({
  collection: 'purchase_orders',
  optimisticConcurrency: true,
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

  // Aggregated Pipeline Tracking Across Items:
  @Prop({ type: Number, default: 0 })
  total_assigned_cartons: number;

  @Prop({ type: Number, default: 0 })
  total_completed_cartons: number;

  @Prop({ type: Number, default: 0 })
  total_qc_passed_items: number;

  @Prop({ type: Number, default: 0 })
  total_packed_cartons: number;

  @Prop({ type: Number, default: 0 })
  total_shipped_cartons: number;

  @Prop({
    type: String,
    enum: Object.values(PurchaseOrderStatus),
    default: PurchaseOrderStatus.DRAFT,
  })
  status: PurchaseOrderStatus;

  @Prop({ type: String, default: '' })
  notes: string;

  @Prop({ type: [SchemaFactory.createForClass(PurchaseOrderActivity)], default: [] })
  activity: PurchaseOrderActivity[];
}

export const PurchaseOrderSchema = SchemaFactory.createForClass(PurchaseOrder);
PurchaseOrderSchema.index({ tenant_id: 1, po_number: 1 });
PurchaseOrderSchema.index({ tenant_id: 1, po_date: -1 });

