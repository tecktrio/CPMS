import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { BatchStatus } from '../../../database/schemas/stock-batch.schema';

export class UpdateStockBatchDto {
  @ApiPropertyOptional({ example: 45.5, description: 'Adjusted remaining quantity' })
  @IsNumber()
  @Min(0)
  @IsOptional()
  available_quantity?: number;

  @ApiPropertyOptional({ example: 'loc-rack-02' })
  @IsString()
  @IsOptional()
  storage_location_id?: string;

  @ApiPropertyOptional({ enum: BatchStatus, example: BatchStatus.RESERVED })
  @IsEnum(BatchStatus)
  @IsOptional()
  batch_status?: BatchStatus;
}
