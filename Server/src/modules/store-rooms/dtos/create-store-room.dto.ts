import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateStoreRoomDto {
  @ApiProperty({ example: 'CR-01', description: 'Unique store room shorthand code' })
  @IsString()
  @IsNotEmpty()
  room_code: string;

  @ApiProperty({
    example: 'Main Storage Room A',
    description: 'Human-readable name of the store room',
  })
  @IsString()
  @IsNotEmpty()
  room_name: string;

  @ApiPropertyOptional({
    example: -18.5,
    description: 'Operating temperature in degrees Celsius (optional)',
  })
  @IsNumber()
  @IsOptional()
  temperature?: number;

  @ApiProperty({
    example: 1000,
    description: 'Maximum storage capacity in units (e.g. cartons/pallets/kg)',
  })
  @IsNumber()
  @Min(1)
  total_capacity_units: number;

  @ApiPropertyOptional({
    example: ['Section A', 'Section B', 'Rack 1'],
    description: 'Divisions or sections inside this store room',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  divisions?: string[];

  @ApiPropertyOptional({
    example: true,
    description: 'Operational status flag (defaults to true)',
  })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
