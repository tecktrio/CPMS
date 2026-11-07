import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

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

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
