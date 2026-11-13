import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class StoreRoomItemDto {
  @ApiProperty({ example: 'item-uuid-001' })
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @ApiPropertyOptional({ example: 'Section 1' })
  @IsString()
  @IsOptional()
  division?: string;

  @ApiPropertyOptional({ example: 50.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  quantity?: number;

  @ApiPropertyOptional({ example: 5, description: 'Minimum item count for this store room' })
  @IsNumber()
  @Min(0)
  @IsOptional()
  min_count?: number;
}

export class UpdateStoreRoomDto {
  @ApiPropertyOptional({ example: 'CR-01-A' })
  @IsString()
  @IsOptional()
  room_code?: string;

  @ApiPropertyOptional({ example: 'Secondary Blast Chiller' })
  @IsString()
  @IsOptional()
  room_name?: string;

  @ApiPropertyOptional({ example: -22.0 })
  @IsNumber()
  @IsOptional()
  temperature?: number;

  @ApiPropertyOptional({ example: 1200 })
  @IsNumber()
  @Min(1)
  @IsOptional()
  total_capacity_units?: number;

  @ApiPropertyOptional({
    example: ['Section A', 'Section B'],
    description: 'Divisions or sections inside this store room',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  divisions?: string[];

  @ApiPropertyOptional({ type: [StoreRoomItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => StoreRoomItemDto)
  @IsOptional()
  items?: StoreRoomItemDto[];

  @ApiPropertyOptional({ type: [String] })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  item_ids?: string[];

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
