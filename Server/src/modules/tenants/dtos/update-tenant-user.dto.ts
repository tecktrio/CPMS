import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class UpdateTenantUserDto {
  @ApiPropertyOptional({
    example: 'tenant-uuid-001',
    description:
      'Tenant organization UUID (optional if provided via X-Tenant-ID header)',
  })
  @IsString()
  @IsOptional()
  tenant_id?: string;

  @ApiProperty({
    example: ['dept-uuid-cold-storage-001'],
    description:
      'The single Department ID assigned to the user within this tenant (1 user = 1 department)',
    type: [String],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(1)
  @IsString({ each: true })
  @IsNotEmpty()
  department_ids: string[];
}

