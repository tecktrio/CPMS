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
  LITER = 'LITER',
  PIECE = 'PIECE',
  CARTOON_BOX = 'CARTOON_BOX',
}

export enum AllowedCategory {
  RAW_MATERIAL = 'RAW_MATERIAL',
  FINISHED_GOOD = 'FINISHED_GOOD',
  PACKAGING = 'PACKAGING',
  ALL = 'ALL',
}

@Schema({ _id: false })
export class StorageLocationDetails {
  @Prop({ type: String, required: true })
  store_room_id: string;

  @Prop({ type: String, required: true, trim: true })
  location_code: string;

  @Prop({ type: String, default: '', trim: true })
  division: string;

  @Prop({ type: String, default: '', trim: true })
  rack_identifier: string;

  @Prop({ type: String, default: '', trim: true })
  shelf_identifier: string;

  @Prop({ type: String, default: '', trim: true })
  bin_identifier: string;

  @Prop({
    type: String,
    enum: Object.values(AllowedCategory),
    default: AllowedCategory.ALL,
  })
  allowed_category: AllowedCategory;

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const StorageLocationDetailsSchema = SchemaFactory.createForClass(
  StorageLocationDetails,
);

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

  @Prop({ type: Number, required: true, min: 0, default: 0 })
  reorder_threshold_quantity: number;

  @Prop({ type: Number, default: 0, min: 0 })
  stock_quantity: number;

  @Prop({ type: StorageLocationDetailsSchema, required: true })
  storage_location_details: StorageLocationDetails;
}

export const ItemSchema = SchemaFactory.createForClass(Item);
ItemSchema.index({ item_id: 1 }, { unique: true });
ItemSchema.index({ tenant_id: 1, sku: 1 }, { unique: true });
ItemSchema.index({ tenant_id: 1 });

