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

  @ApiPropertyOptional({ example: 100 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  stock_quantity?: number;

  @ApiPropertyOptional({
    example: 'https://my-bucket.s3.amazonaws.com/items/flour.jpg',
  })
  @IsString()
  @IsOptional()
  image_url?: string;

  @ApiPropertyOptional({ type: StorageLocationDetailsDto })
  @ValidateNested()
  @Type(() => StorageLocationDetailsDto)
  @IsOptional()
  storage_location_details?: StorageLocationDetailsDto;
}
