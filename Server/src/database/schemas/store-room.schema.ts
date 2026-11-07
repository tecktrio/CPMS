import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type StoreRoomDocument = StoreRoom & Document;

@Schema({
  collection: 'store_rooms',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class StoreRoom {
  @Prop({ type: String, default: uuidv4, unique: true })
  store_room_id: string;

  @Prop({ type: String, required: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true })
  room_code: string;

  @Prop({ type: String, required: true, trim: true })
  room_name: string;

  @Prop({ type: Number, required: false, default: null })
  temperature?: number; // in Celsius (optional, e.g. -18.0)

  @Prop({ type: Number, required: true, min: 0 })
  total_capacity_units: number;

  @Prop({ type: [String], default: [] })
  divisions: string[]; // Divisions / sections / areas inside this store room

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const StoreRoomSchema = SchemaFactory.createForClass(StoreRoom);
StoreRoomSchema.index({ store_room_id: 1 }, { unique: true });
StoreRoomSchema.index({ tenant_id: 1, room_code: 1 }, { unique: true });
StoreRoomSchema.index({ tenant_id: 1 });

