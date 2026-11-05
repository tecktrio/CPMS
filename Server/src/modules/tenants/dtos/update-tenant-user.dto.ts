import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsNotEmpty, IsOptional, IsString } from 'class-validator';

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
    example: ['dept-uuid-cold-storage-001', 'dept-uuid-packaging-002'],
    description:
      'Updated list of valid Department IDs assigned to the user within this tenant',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  department_ids: string[];
}

