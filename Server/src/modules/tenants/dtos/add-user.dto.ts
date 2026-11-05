import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class AddUserDto {
  @ApiPropertyOptional({
    example: 'tenant-uuid-001',
    description:
      'Tenant organization UUID where user is being added (optional if provided via X-Tenant-ID header)',
  })
  @IsString()
  @IsOptional()
  tenant_id?: string;

  @ApiProperty({
    example: 'operator.jane@example.com',
    description: 'Email address of the user to add to the tenant organization',
  })
  @IsEmail()
  @IsNotEmpty()
  email_address: string;

  @ApiProperty({
    example: ['dept-uuid-cold-storage-001', 'dept-uuid-quality-control-002'],
    description:
      'List of Department IDs assigned to the user within this tenant. Multiple departments can be specified.',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  department_ids: string[];
}

