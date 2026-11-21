import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type PackagingMaterialDocument = PackagingMaterial & Document;

@Schema({
  collection: 'packaging_materials',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class PackagingMaterial {
  @Prop({ type: String, default: uuidv4, unique: true })
  material_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true })
  name: string;

  @Prop({ type: Boolean, default: false })
  is_preset: boolean;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const PackagingMaterialSchema =
  SchemaFactory.createForClass(PackagingMaterial);
PackagingMaterialSchema.index({ tenant_id: 1, name: 1 }, { unique: true });
PackagingMaterialSchema.index({ tenant_id: 1 });

