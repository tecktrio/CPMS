import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import {
  ItemType,
  MeasurementUnit,
} from '../../../database/schemas/item.schema';

export class CreateItemDto {
  @ApiProperty({
    example: 'RM-FLOUR-001',
    description: 'Unique product/material SKU identifier within tenant',
  })
  @IsString()
  @IsNotEmpty()
  sku: string;

  @ApiProperty({
    example: 'Organic Wheat Flour',
    description: 'Item name or title',
  })
  @IsString()
  @IsNotEmpty()
  item_name: string;

  @ApiProperty({
    enum: ItemType,
    example: ItemType.RAW_MATERIAL,
    description: 'Item classification',
  })
  @IsEnum(ItemType)
  @IsNotEmpty()
  item_type: ItemType;

  @ApiProperty({
    enum: MeasurementUnit,
    example: MeasurementUnit.KILOGRAM,
    description: 'Unit of measure',
  })
  @IsEnum(MeasurementUnit)
  @IsNotEmpty()
  measurement_unit: MeasurementUnit;

  @ApiPropertyOptional({
    example: 250,
    description: 'Stock threshold triggering reorder shortfall alerts',
  })
  @IsNumber()
  @Min(0)
  @IsOptional()
  reorder_threshold_quantity?: number;

  @ApiPropertyOptional({
    example: 'High quality organic wheat flour for bakery products',
    description: 'Item description',
  })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({
    example: false,
    description: 'Whether the item has ingredients',
  })
  @IsBoolean()
  @IsOptional()
  has_ingredients?: boolean;

  @ApiPropertyOptional({
    example: ['item-uuid-1', 'item-uuid-2'],
    description: 'List of raw material item IDs used as ingredients',
  })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  ingredients?: string[];

  @ApiPropertyOptional({
    example: 'https://my-bucket.s3.amazonaws.com/items/flour.jpg',
    description: 'Image URL of the item',
  })
  @IsString()
  @IsOptional()
  image_url?: string;
}
