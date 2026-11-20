import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type QcReportDocument = QcReport & Document;

@Schema({
  collection: 'qc_reports',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class QcReport {
  @Prop({ type: String, default: uuidv4, unique: true })
  qc_report_id: string;

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

  @Prop({ type: String, required: true })
  inspector_user_id: string;

  @Prop({ type: String, required: true })
  inspector_name: string;

  @Prop({
    type: String,
    enum: ['PASSED', 'FAILED', 'CONDITIONAL_PASS'],
    required: true,
  })
  status: string;

  @Prop({ type: Number, required: true, min: 0 })
  inspected_cartons: number;

  @Prop({ type: Number, default: 0, min: 0 })
  rejected_cartons: number;

  @Prop({ type: String, default: '' })
  remarks: string;

  @Prop({ type: [String], default: [] })
  attachment_urls: string[];

  @Prop({ type: Date, default: Date.now })
  inspected_at: Date;
}

export const QcReportSchema = SchemaFactory.createForClass(QcReport);

QcReportSchema.index({ tenant_id: 1, po_id: 1 });
QcReportSchema.index({ tenant_id: 1, item_id: 1 });

