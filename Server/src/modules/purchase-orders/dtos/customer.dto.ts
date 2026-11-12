import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsBoolean } from 'class-validator';

export class CreateCustomerDto {
  @ApiProperty({
    example: 'KDM TRADING, MALTA',
    description: 'Name of customer / consignee',
  })
  @IsString()
  @IsNotEmpty()
  customer_name: string;

  @ApiPropertyOptional({
    example: 'Valletta Industrial Estate, Malta',
    description: 'Customer delivery address',
  })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({
    example: '+356 9912 3456 / contact@kdmtrading.com',
    description: 'Contact phone or email',
  })
  @IsString()
  @IsOptional()
  contact_details?: string;
}

export class UpdateCustomerDto {
  @ApiPropertyOptional({ example: 'KDM TRADING, MALTA' })
  @IsString()
  @IsOptional()
  customer_name?: string;

  @ApiPropertyOptional({ example: 'Valletta, Malta' })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({ example: '+356 9912 3456' })
  @IsString()
  @IsOptional()
  contact_details?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}

