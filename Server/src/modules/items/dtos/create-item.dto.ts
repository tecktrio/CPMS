import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
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
  AllowedCategory,
} from '../../../database/schemas/item.schema';

export class StorageLocationDetailsDto {
  @ApiProperty({
    example: 'store-room-uuid-001',
    description: 'UUID of the assigned cold room',
  })
  @IsString()
  @IsNotEmpty()
  store_room_id: string;

  @ApiProperty({
    example: 'A-01-02',
    description: 'Physical location code within the store room',
  })
  @IsString()
  @IsNotEmpty()
  location_code: string;

  @ApiPropertyOptional({ example: 'RACK-A' })
  @IsString()
  @IsOptional()
  rack_identifier?: string;

  @ApiPropertyOptional({ example: 'SHELF-01' })
  @IsString()
  @IsOptional()
  shelf_identifier?: string;

  @ApiPropertyOptional({ example: 'BIN-02' })
  @IsString()
  @IsOptional()
  bin_identifier?: string;

  @ApiPropertyOptional({
    enum: AllowedCategory,
    example: AllowedCategory.ALL,
    description: 'Allowed category in this location',
  })
  @IsEnum(AllowedCategory)
  @IsOptional()
  allowed_category?: AllowedCategory;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}

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
    description: 'Unit of measure for stock quantity',
  })
  @IsEnum(MeasurementUnit)
  @IsNotEmpty()
  measurement_unit: MeasurementUnit;

  @ApiProperty({
    example: 250,
    description: 'Stock threshold triggering reorder shortfall alerts',
  })
  @IsNumber()
  @Min(0)
  reorder_threshold_quantity: number;

  @ApiProperty({ type: StorageLocationDetailsDto })
  @ValidateNested()
  @Type(() => StorageLocationDetailsDto)
  @IsNotEmpty()
  storage_location_details: StorageLocationDetailsDto;
}
