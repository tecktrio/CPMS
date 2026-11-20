import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateProductionAssignmentDto {
  @ApiProperty({ description: 'Purchase Order ID' })
  @IsString()
  @IsNotEmpty()
  po_id: string;

  @ApiProperty({ description: 'Item ID within the PO' })
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @ApiProperty({ description: 'User ID of the assigned Supervisor' })
  @IsString()
  @IsNotEmpty()
  supervisor_user_id: string;

  @ApiProperty({ description: 'Cartons assigned to this supervisor', minimum: 1 })
  @IsNumber()
  @Min(1)
  assigned_cartons: number;

  @ApiProperty({ description: 'Optional operational notes for the supervisor', required: false })
  @IsString()
  @IsOptional()
  notes?: string;
}

export class UpdateProgressDto {
  @ApiProperty({ description: 'Carton quantity completed so far', minimum: 0 })
  @IsNumber()
  @Min(0)
  completed_cartons: number;
}

