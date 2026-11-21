import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type EmergencyContactDocument = EmergencyContact & Document;

@Schema({
  collection: 'emergency_contacts',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class EmergencyContact {
  @Prop({ type: String, default: uuidv4, unique: true })
  contact_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true })
  title: string;

  @Prop({ type: String, default: '', trim: true })
  subtitle: string;

  @Prop({ type: String, required: true, trim: true })
  phone_number: string;

  @Prop({ type: String, default: 'warning', trim: true })
  icon_type: string;

  @Prop({ type: Number, default: 0 })
  priority_order: number;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const EmergencyContactSchema =
  SchemaFactory.createForClass(EmergencyContact);
EmergencyContactSchema.index({ tenant_id: 1, is_active: 1, priority_order: 1 });

