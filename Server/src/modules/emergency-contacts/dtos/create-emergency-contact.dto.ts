import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateEmergencyContactDto {
  @ApiProperty({
    example: 'Facility Security & Control',
    description: 'Title of the emergency contact or unit',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  title: string;

  @ApiPropertyOptional({
    example: 'Control Room • Ext. 101',
    description: 'Subtitle, person name, location, or extension',
  })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  subtitle?: string;

  @ApiProperty({
    example: '+1 (800) 555-0199',
    description: 'Phone number to call directly',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone_number: string;

  @ApiPropertyOptional({
    example: 'security',
    description: 'Visual category/icon: security, safety, medical, or general',
  })
  @IsString()
  @IsOptional()
  icon_type?: string;

  @ApiPropertyOptional({
    example: 0,
    description: 'Display order priority',
  })
  @IsNumber()
  @IsOptional()
  priority_order?: number;
}

