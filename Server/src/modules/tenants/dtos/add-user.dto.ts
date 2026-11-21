import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
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
    example: ['dept-uuid-quality-control-002'],
    description:
      'The single Department ID assigned to the user within this tenant (1 user = 1 department).',
    type: [String],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(1)
  @IsString({ each: true })
  @IsNotEmpty()
  department_ids: string[];
}

