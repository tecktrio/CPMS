import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type PermissionDocument = Permission & Document;

@Schema({
  collection: 'permissions',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class Permission {
  @Prop({ type: String, required: true, unique: true })
  permission_id: string; // e.g. "permission.item.create"

  @Prop({ type: String, required: true })
  module: string; // e.g. "Items", "StoreRooms", "StockBatches", "Departments"

  @Prop({ type: String, required: true })
  action: string; // "CREATE" | "READ" | "UPDATE" | "DELETE" | "ALLOCATE"

  @Prop({ type: String, required: true })
  display_name: string; // e.g. "Create Item"

  @Prop({ type: String, required: true })
  description: string;

  @Prop({ type: Boolean, default: true })
  is_system_default: boolean;
}

export const PermissionSchema = SchemaFactory.createForClass(Permission);
PermissionSchema.index({ permission_id: 1 }, { unique: true });
PermissionSchema.index({ module: 1 });

