import { IsBoolean, IsDateString, IsNotEmpty, IsInt, IsOptional, IsString, Min, ValidateIf } from 'class-validator';
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
  @IsInt()
  @Min(1)
  assigned_cartons: number;

  @ApiProperty({ description: 'Optional operational notes for the supervisor', required: false })
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiProperty({ description: 'Target/scheduled date for this assignment (ISO string)' })
  @IsDateString({ strict: true })
  target_date: string;
}

export class UpdateProgressDto {
  @ApiProperty({ description: 'Carton quantity completed so far', minimum: 0 })
  @IsInt()
  @Min(0)
  completed_cartons: number;

  @IsOptional()
  @IsBoolean()
  mark_done?: boolean;
}

export class UpdateAssignmentDto {
  @ApiProperty({ description: 'Reassign to another supervisor user ID', required: false })
  @IsString()
  @IsOptional()
  supervisor_user_id?: string;

  @ApiProperty({ description: 'Updated assigned cartons', minimum: 1, required: false })
  @IsInt()
  @Min(1)
  @IsOptional()
  assigned_cartons?: number;

  @ApiProperty({ description: 'Updated operational notes', required: false })
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiProperty({ description: 'Updated target/scheduled date (ISO string)', required: false })
  @ValidateIf((_, value) => value !== undefined)
  @IsDateString({ strict: true })
  target_date?: string;
}

