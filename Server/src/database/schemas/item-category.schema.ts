import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type ItemCategoryDocument = ItemCategory & Document;

@Schema({
  collection: 'item_categories',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class ItemCategory {
  @Prop({ type: String, default: uuidv4, unique: true })
  category_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true, uppercase: true })
  code: string;

  @Prop({ type: String, required: true, trim: true })
  label: string;

  @Prop({ type: Boolean, default: false })
  is_preset: boolean;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const ItemCategorySchema = SchemaFactory.createForClass(ItemCategory);
ItemCategorySchema.index({ category_id: 1 }, { unique: true });
ItemCategorySchema.index({ tenant_id: 1, code: 1 }, { unique: true });
ItemCategorySchema.index({ tenant_id: 1 });

