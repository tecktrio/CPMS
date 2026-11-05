import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import {
  ItemType,
  MeasurementUnit,
} from '../../../database/schemas/item.schema';
import { StorageLocationDetailsDto } from './create-item.dto';

export class UpdateItemDto {
  @ApiPropertyOptional({ example: 'RM-FLOUR-001' })
  @IsString()
  @IsOptional()
  sku?: string;

  @ApiPropertyOptional({ example: 'Organic Wheat Flour Grade A' })
  @IsString()
  @IsOptional()
  item_name?: string;

  @ApiPropertyOptional({ enum: ItemType, example: ItemType.RAW_MATERIAL })
  @IsEnum(ItemType)
  @IsOptional()
  item_type?: ItemType;

  @ApiPropertyOptional({
    enum: MeasurementUnit,
    example: MeasurementUnit.KILOGRAM,
  })
  @IsEnum(MeasurementUnit)
  @IsOptional()
  measurement_unit?: MeasurementUnit;

  @ApiPropertyOptional({ example: 300 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  reorder_threshold_quantity?: number;

  @ApiPropertyOptional({ type: StorageLocationDetailsDto })
  @ValidateNested()
  @Type(() => StorageLocationDetailsDto)
  @IsOptional()
  storage_location_details?: StorageLocationDetailsDto;
}
