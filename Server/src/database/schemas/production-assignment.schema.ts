import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type ProductionAssignmentDocument = ProductionAssignment & Document;

@Schema({ _id: false })
export class ProductionProgressEntry {
  @Prop({ type: Date, required: true })
  at: Date;

  @Prop({ type: String, required: true })
  user_id: string;

  @Prop({ type: String, required: true })
  supervisor_name: string;

  @Prop({ type: Number, required: true })
  previous_cartons: number;

  @Prop({ type: Number, required: true })
  completed_cartons: number;
}

@Schema({
  collection: 'production_assignments',
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
export class ProductionAssignment {
  declare created_at?: Date;

  @Prop({ type: [SchemaFactory.createForClass(ProductionProgressEntry)], default: [] })
  progress_history: ProductionProgressEntry[];

  @Prop({ type: String, default: uuidv4, unique: true })
  assignment_id: string;

  @Prop({ type: String, required: true, index: true })
  tenant_id: string;

  @Prop({ type: String, required: true, index: true })
  po_id: string;

  @Prop({ type: String, required: true })
  po_number: string;

  @Prop({ type: String, required: true })
  item_id: string;

  @Prop({ type: String, required: true })
  item_name: string;

  @Prop({ type: String, required: true, index: true })
  supervisor_user_id: string;

  @Prop({ type: String, required: true })
  supervisor_name: string;

  @Prop({ type: Number, required: true, min: 1 })
  assigned_cartons: number;

  @Prop({ type: Number, default: 0, min: 0 })
  completed_cartons: number;

  @Prop({
    type: String,
    enum: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
    default: 'PENDING',
  })
  status: string;

  @Prop({ type: String, required: true })
  assigned_by_user_id: string;

  @Prop({ type: String, default: '' })
  notes: string;

  @Prop({ type: Date, default: null })
  target_date: Date | null;

  @Prop({ type: Date, default: null })
  completed_at: Date | null;
}

export const ProductionAssignmentSchema =
  SchemaFactory.createForClass(ProductionAssignment);

ProductionAssignmentSchema.index({ tenant_id: 1, po_id: 1 });
ProductionAssignmentSchema.index({ tenant_id: 1, supervisor_user_id: 1 });

