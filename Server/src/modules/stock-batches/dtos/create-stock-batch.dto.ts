import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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
  @ApiProperty({ example: 'item-uuid-001', description: 'Item UUID reference' })
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @ApiProperty({
    example: 'BATCH-2026-11-A',
    description: 'Unique batch or lot code',
  })
  @IsString()
  @IsNotEmpty()
  batch_number: string;

  @ApiProperty({
    example: 'loc-rack-01',
    description: 'Storage location slot identifier',
  })
  @IsString()
  @IsNotEmpty()
  storage_location_id: string;

  @ApiProperty({
    example: 'storeroom-uuid-001',
    description: 'Target cold room UUID',
  })
  @IsString()
  @IsNotEmpty()
  store_room_id: string;

  @ApiProperty({
    example: 50.0,
    description: 'Received quantity to stock into inventory',
  })
  @IsNumber()
  @Min(0.01)
  available_quantity: number;

  @ApiProperty({
    example: '2026-11-01T00:00:00.000Z',
    description: 'Manufacturing date (ISO 8601)',
  })
  @IsDateString()
  @IsNotEmpty()
  manufacturing_date: string;

  @ApiProperty({
    example: '2026-12-15T00:00:00.000Z',
    description: 'Expiry date used for FEFO sorting (must be after manufacturing date)',
  })
  @IsDateString()
  @IsNotEmpty()
  expiry_date: string;

  @ApiPropertyOptional({
    enum: BatchStatus,
    example: BatchStatus.AVAILABLE,
    description: 'Initial batch status',
  })
  @IsEnum(BatchStatus)
  @IsOptional()
  batch_status?: BatchStatus;
}
