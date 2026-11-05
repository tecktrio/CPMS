import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type DepartmentDocument = Department & Document;

@Schema({
  collection: 'departments',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    },
  },
})
export class Department {
  @Prop({ type: String, default: uuidv4, unique: true })
  department_id: string;

  @Prop({ type: String, required: true, index: true })
  tenant_id: string;

  @Prop({ type: String, required: true, trim: true })
  department_name: string;

  @Prop({ type: String, default: '', trim: true })
  description: string;

  @Prop({ type: [String], default: [] })
  permission_ids: string[];

  @Prop({ type: Boolean, default: true })
  is_active: boolean;
}

export const DepartmentSchema = SchemaFactory.createForClass(Department);
DepartmentSchema.index({ department_id: 1 }, { unique: true });
DepartmentSchema.index({ tenant_id: 1, department_name: 1 }, { unique: true });
DepartmentSchema.index({ tenant_id: 1, is_active: 1 });

