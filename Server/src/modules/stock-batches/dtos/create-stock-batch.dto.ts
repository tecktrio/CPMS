import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { BatchStatus } from '../../../database/schemas/stock-batch.schema';

export class CreateStockBatchDto {
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @IsString()
  @IsNotEmpty()
  batch_number: string;

  @IsString()
  @IsNotEmpty()
  storage_location_id: string;

  @IsString()
  @IsNotEmpty()
  store_room_id: string;

  @IsNumber()
  @Min(0.01)
  available_quantity: number;

  @IsDateString()
  @IsNotEmpty()
  manufacturing_date: string;

  @IsDateString()
  @IsNotEmpty()
  expiry_date: string;

  @IsEnum(BatchStatus)
  @IsOptional()
  batch_status?: BatchStatus;
}

