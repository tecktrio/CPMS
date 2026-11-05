import { ApiProperty } from '@nestjs/swagger';
import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class BatchDeductionItemDto {
  @ApiProperty({
    example: 'batch-uuid-001',
    description: 'Target stock batch UUID to deduct from',
  })
  @IsString()
  @IsNotEmpty()
  batch_id: string;

  @ApiProperty({
    example: 25.0,
    description: 'Exact quantity confirmed for deduction',
  })
  @IsNumber()
  @Min(0.01)
  deduct_quantity: number;
}

export class DeductBatchesDto {
  @ApiProperty({
    type: [BatchDeductionItemDto],
    description: 'List of confirmed batch deduction allocations (Option B)',
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BatchDeductionItemDto)
  @IsNotEmpty()
  allocations: BatchDeductionItemDto[];

  @ApiProperty({
    example: 'Production BOM consumption for PO #1002',
    description: 'Business reason / notes for the inventory deduction',
  })
  @IsString()
  @IsNotEmpty()
  reason: string;
}
