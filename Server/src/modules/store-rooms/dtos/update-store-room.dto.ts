import { ApiPropertyOptional } from '@nestjs/swagger';
import {
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

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
