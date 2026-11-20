import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreatePackagingMaterialDto {
  @ApiProperty({ example: 'Duplex', description: 'Packaging material name' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdatePackagingMaterialDto {
  @ApiPropertyOptional({ example: 'Duplex Box' })
  @IsString()
  @IsOptional()
  name?: string;
}

