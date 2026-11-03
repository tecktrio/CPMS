import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

export type OtpRecordDocument = OtpRecord & Document;

@Schema({
  collection: 'otp_records',
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
})
export class OtpRecord {
  @Prop({ type: String, default: uuidv4, unique: true })
  record_id: string;

  @Prop({ type: String, required: true, lowercase: true, trim: true })
  email_address: string;

  @Prop({ type: String, required: true })
  otp_code: string;

  @Prop({ type: Date, required: true })
  expires_at: Date;

  @Prop({ type: Boolean, default: false })
  is_verified: boolean;
}

export const OtpRecordSchema = SchemaFactory.createForClass(OtpRecord);
OtpRecordSchema.index({ email_address: 1 });
OtpRecordSchema.index({ expires_at: 1 }, { expireAfterSeconds: 0 }); // MongoDB TTL auto-cleanup

