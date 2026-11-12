import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import {
  ItemType,
  MeasurementUnit,
} from '../../../database/schemas/item.schema';

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

  @ApiPropertyOptional({ example: 'Updated item description' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  has_ingredients?: boolean;

  @ApiPropertyOptional({ example: ['item-uuid-1', 'item-uuid-2'] })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  ingredients?: string[];

  @ApiPropertyOptional({
    example: 'https://my-bucket.s3.amazonaws.com/items/flour.jpg',
  })
  @IsString()
  @IsOptional()
  image_url?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
