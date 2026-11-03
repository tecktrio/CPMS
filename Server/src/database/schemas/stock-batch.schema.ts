import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export enum BatchStatus {
  AVAILABLE = 'AVAILABLE',
  RESERVED = 'RESERVED',
  EXPIRED = 'EXPIRED',
  DISPATCHED = 'DISPATCHED',
}

export type StockBatchDocument = StockBatch & Document;

@Schema({
  collection: 'stock_batches',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class StockBatch {
  @Prop({ type: String, default: uuidv4, unique: true })
  batch_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true })
  item_id: string;

  @Prop({ type: String, required: true, trim: true, uppercase: true })
  batch_number: string;

  @Prop({ type: String, required: true })
  storage_location_id: string;

  @Prop({ type: String, required: true })
  store_room_id: string;

  @Prop({ type: Number, required: true, min: 0 })
  available_quantity: number;

  @Prop({ type: Date, required: true })
  manufacturing_date: Date;

  @Prop({ type: Date, required: true })
  expiry_date: Date; // Critical for FEFO sorting

  @Prop({
    type: String,
    enum: Object.values(BatchStatus),
    default: BatchStatus.AVAILABLE,
  })
  batch_status: BatchStatus;
}

export const StockBatchSchema = SchemaFactory.createForClass(StockBatch);
StockBatchSchema.index({ batch_id: 1 }, { unique: true });
StockBatchSchema.index({ tenant_id: 1, item_id: 1, expiry_date: 1 }); // FEFO index!
StockBatchSchema.index({ tenant_id: 1, batch_number: 1 });
StockBatchSchema.index({ tenant_id: 1, store_room_id: 1 });

