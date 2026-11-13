import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export enum ItemType {
  RAW_MATERIAL = 'RAW_MATERIAL',
  FINISHED_GOOD = 'FINISHED_GOOD',
  PACKAGING = 'PACKAGING',
}

export enum MeasurementUnit {
  KILOGRAM = 'KILOGRAM',
  GRAM = 'GRAM',
  LITER = 'LITER',
  LITRE = 'LITRE',
  MILLILITER = 'MILLILITER',
  MILLILITRE = 'MILLILITRE',
  PIECE = 'PIECE',
  UNIT = 'UNIT',
  CARTOON_BOX = 'CARTOON_BOX',
}

export type ItemDocument = Item & Document;

@Schema({
  collection: 'items',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class Item {
  @Prop({ type: String, default: uuidv4, unique: true })
  item_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true, uppercase: true })
  sku: string;

  @Prop({ type: String, required: true, trim: true })
  item_name: string;

  @Prop({
    type: String,
    enum: Object.values(ItemType),
    required: true,
  })
  item_type: ItemType;

  @Prop({
    type: String,
    enum: Object.values(MeasurementUnit),
    required: true,
  })
  measurement_unit: MeasurementUnit;

  @Prop({ type: Number, default: 1, min: 0 })
  quantity: number;

  @Prop({ type: Number, required: false, min: 0, default: 0 })
  reorder_threshold_quantity: number;

  @Prop({ type: String, default: '' })
  description: string;

  @Prop({ type: Boolean, default: false })
  has_ingredients: boolean;

  @Prop({ type: Array, default: [] })
  ingredients: Array<{ item_id: string; quantity: number; unit?: string }>;

  @Prop({ type: String, default: null })
  image_url: string | null;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const ItemSchema = SchemaFactory.createForClass(Item);
ItemSchema.index({ item_id: 1 }, { unique: true });
ItemSchema.index({ tenant_id: 1, sku: 1 }, { unique: true });
ItemSchema.index({ tenant_id: 1 });

