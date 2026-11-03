import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { BatchStatus } from '../../../database/schemas/stock-batch.schema';

export class UpdateStockBatchDto {
  @IsNumber()
  @Min(0)
  @IsOptional()
  available_quantity?: number;

  @IsString()
  @IsOptional()
  storage_location_id?: string;

  @IsEnum(BatchStatus)
  @IsOptional()
  batch_status?: BatchStatus;
}

