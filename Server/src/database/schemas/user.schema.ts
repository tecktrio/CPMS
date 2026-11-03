import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export enum UserAccountStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  SUSPENDED = 'SUSPENDED',
}

export type UserDocument = User & Document;

@Schema({
  collection: 'users',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  toJSON: {
    transform: (_, ret: Record<string, any>) => {
      delete ret._id;
      delete ret.__v;
      delete ret.password_hash;
      return ret;
    },
  },
})
export class User {
  @Prop({ type: String, default: uuidv4, unique: true })
  user_id: string;

  @Prop({ type: String, required: true, trim: true })
  full_name: string;

  @Prop({ type: String, required: true, unique: true, lowercase: true, trim: true })
  email_address: string;

  @Prop({ type: String, required: true })
  password_hash: string;

  @Prop({ type: String, default: null })
  department_id: string | null;

  @Prop({
    type: String,
    enum: Object.values(UserAccountStatus),
    default: UserAccountStatus.ACTIVE,
  })
  account_status: UserAccountStatus;
}

export const UserSchema = SchemaFactory.createForClass(User);
UserSchema.index({ email_address: 1 }, { unique: true });
UserSchema.index({ user_id: 1 }, { unique: true });

