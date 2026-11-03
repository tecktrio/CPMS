import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type TenantDocument = Tenant & Document;

@Schema({
  collection: 'tenants',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class Tenant {
  @Prop({ type: String, default: uuidv4, unique: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true })
  company_name: string;

  @Prop({ type: String, required: true })
  admin_user_id: string;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const TenantSchema = SchemaFactory.createForClass(Tenant);
TenantSchema.index({ tenant_id: 1 }, { unique: true });
TenantSchema.index({ admin_user_id: 1 });

