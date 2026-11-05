import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateStoreRoomDto {
  @ApiProperty({ example: 'CR-01', description: 'Unique cold room shorthand code' })
  @IsString()
  @IsNotEmpty()
  room_code: string;

  @ApiProperty({
    example: 'Main Deep Freeze -20C',
    description: 'Human-readable name of the cold storage room',
  })
  @IsString()
  @IsNotEmpty()
  room_name: string;

  @ApiProperty({
    example: -18.5,
    description: 'Operating temperature in degrees Celsius',
  })
  @IsNumber()
  @IsNotEmpty()
  temperature: number;

  @ApiProperty({
    example: 1000,
    description: 'Maximum storage capacity in units (e.g. cartons/pallets/kg)',
  })
  @IsNumber()
  @Min(1)
  total_capacity_units: number;

  @ApiPropertyOptional({
    example: true,
    description: 'Operational status flag (defaults to true)',
  })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
