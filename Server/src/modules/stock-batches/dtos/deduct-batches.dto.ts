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
  @IsString()
  @IsNotEmpty()
  batch_id: string;

  @IsNumber()
  @Min(0.01)
  deduct_quantity: number;
}

export class DeductBatchesDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BatchDeductionItemDto)
  @IsNotEmpty()
  allocations: BatchDeductionItemDto[];

  @IsString()
  @IsNotEmpty()
  reason: string; // e.g. "Production BOM allocation for PO #1002" or "Spoilage/Dispatch"
}

