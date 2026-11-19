import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateItemCategoryDto {
  @ApiProperty({ example: 'SPARE_PARTS', description: 'Unique category code within tenant' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ example: 'Spare Parts', description: 'Display label for category' })
  @IsString()
  @IsNotEmpty()
  label: string;
}

export class UpdateItemCategoryDto {
  @ApiPropertyOptional({ example: 'Spare Parts & Tools' })
  @IsString()
  @IsOptional()
  label?: string;
}

