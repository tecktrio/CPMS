import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateDepartmentDto {
  @ApiPropertyOptional({
    example: 'Cold Storage & Inventory Unit',
    description: 'Updated department name',
  })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  department_name?: string;

  @ApiPropertyOptional({
    example: 'Updated scope of department tasks',
    description: 'Updated description',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({
    example: [
      'permission.item.read',
      'permission.storeroom.read',
      'permission.batch.read',
    ],
    description: 'Updated list of permission IDs allocated to this department',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  permission_ids?: string[];

  @ApiPropertyOptional({
    example: true,
    description: 'Active status of the department',
  })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}

