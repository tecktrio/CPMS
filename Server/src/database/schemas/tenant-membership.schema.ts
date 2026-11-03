import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type TenantMembershipDocument = TenantMembership & Document;

@Schema({
  collection: 'tenant_memberships',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class TenantMembership {
  @Prop({ type: String, default: uuidv4, unique: true })
  membership_id: string;

  @Prop({ type: String, required: true })
  user_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: [String], default: [] })
  department_ids: string[];

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const TenantMembershipSchema =
  SchemaFactory.createForClass(TenantMembership);
TenantMembershipSchema.index({ membership_id: 1 }, { unique: true });
TenantMembershipSchema.index({ user_id: 1, tenant_id: 1 }, { unique: true });
TenantMembershipSchema.index({ tenant_id: 1 });

