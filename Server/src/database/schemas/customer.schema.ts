import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type CustomerDocument = Customer & Document;

@Schema({
  collection: 'customers',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class Customer {
  @Prop({ type: String, default: uuidv4, unique: true })
  customer_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true })
  customer_name: string;

  @Prop({ type: String, default: '', trim: true })
  address: string;

  @Prop({ type: String, default: '', trim: true })
  contact_details: string;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const CustomerSchema = SchemaFactory.createForClass(Customer);
CustomerSchema.index({ customer_id: 1 }, { unique: true });
CustomerSchema.index({ tenant_id: 1, customer_name: 1 });
CustomerSchema.index({ tenant_id: 1 });

