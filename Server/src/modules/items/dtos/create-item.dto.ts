import {
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
  @IsString()
  @IsNotEmpty()
  store_room_id: string;

  @IsString()
  @IsNotEmpty()
  location_code: string;

  @IsString()
  @IsOptional()
  rack_identifier?: string;

  @IsString()
  @IsOptional()
  shelf_identifier?: string;

  @IsString()
  @IsOptional()
  bin_identifier?: string;

  @IsEnum(AllowedCategory)
  @IsOptional()
  allowed_category?: AllowedCategory;
}

export class CreateItemDto {
  @IsString()
  @IsNotEmpty()
  sku: string;

  @IsString()
  @IsNotEmpty()
  item_name: string;

  @IsEnum(ItemType)
  @IsNotEmpty()
  item_type: ItemType;

  @IsEnum(MeasurementUnit)
  @IsNotEmpty()
  measurement_unit: MeasurementUnit;

  @IsNumber()
  @Min(0)
  reorder_threshold_quantity: number;

  @ValidateNested()
  @Type(() => StorageLocationDetailsDto)
  @IsNotEmpty()
  storage_location_details: StorageLocationDetailsDto;
}

