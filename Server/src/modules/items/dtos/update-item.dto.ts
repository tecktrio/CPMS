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
  @IsString()
  @IsOptional()
  sku?: string;

  @IsString()
  @IsOptional()
  item_name?: string;

  @IsEnum(ItemType)
  @IsOptional()
  item_type?: ItemType;

  @IsEnum(MeasurementUnit)
  @IsOptional()
  measurement_unit?: MeasurementUnit;

  @IsNumber()
  @Min(0)
  @IsOptional()
  reorder_threshold_quantity?: number;

  @ValidateNested()
  @Type(() => StorageLocationDetailsDto)
  @IsOptional()
  storage_location_details?: StorageLocationDetailsDto;
}

