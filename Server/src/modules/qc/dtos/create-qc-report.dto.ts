import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateQcReportDto {
  @ApiProperty({ description: 'Purchase Order ID' })
  @IsString()
  @IsNotEmpty()
  po_id: string;

  @ApiProperty({ description: 'Item ID within the PO' })
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @ApiProperty({
    description: 'Inspection outcome status',
    enum: ['PASSED', 'FAILED', 'CONDITIONAL_PASS'],
  })
  @IsString()
  @IsNotEmpty()
  status: 'PASSED' | 'FAILED' | 'CONDITIONAL_PASS';

  @ApiProperty({ description: 'Quantity of cartons audited/inspected', minimum: 0 })
  @IsNumber()
  @Min(0)
  inspected_cartons: number;

  @ApiProperty({ description: 'Quantity of cartons rejected', minimum: 0, required: false })
  @IsNumber()
  @Min(0)
  @IsOptional()
  rejected_cartons?: number;

  @ApiProperty({ description: 'Quality inspection remarks or lab notes', required: false })
  @IsString()
  @IsOptional()
  remarks?: string;

  @ApiProperty({ description: 'Attachment URLs (photos, certs)', required: false, type: [String] })
  @IsOptional()
  attachment_urls?: string[];
}

