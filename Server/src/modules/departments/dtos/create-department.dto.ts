import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateDepartmentDto {
  @ApiProperty({
    example: 'Cold Storage Operations',
    description: 'Human-readable unique name of the department within the tenant',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  department_name: string;

  @ApiPropertyOptional({
    example: 'Manages raw material inward receiving, cold room storage, and FEFO picking',
    description: 'Detailed description of department responsibilities',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;

  @ApiProperty({
    example: [
      'permission.item.read',
      'permission.storeroom.read',
      'permission.batch.create',
      'permission.batch.read',
      'permission.batch.deduct',
    ],
    description:
      'Array of system permission IDs granted to this department. Members assigned to this department inherit these permissions.',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  permission_ids: string[];
}

