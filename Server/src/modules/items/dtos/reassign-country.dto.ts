import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class ReassignCountryDto {
  @ApiProperty({
    description: 'Existing country name to reassign from',
    example: 'India',
  })
  @IsString()
  @IsNotEmpty()
  from_country: string;

  @ApiPropertyOptional({
    description: 'New country name to reassign to (leave empty for Global/None)',
    example: 'United States',
  })
  @IsString()
  @IsOptional()
  to_country?: string;
}

