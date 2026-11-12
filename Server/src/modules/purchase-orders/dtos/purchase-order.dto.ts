import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PurchaseOrderStatus } from '../../../database/schemas/purchase-order.schema';

export class PurchaseOrderItemDto {
  @ApiProperty({ example: 'item-uuid-1', description: 'Catalog Item ID' })
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @ApiProperty({ example: 'Achinga Payar Thoran 400 gm' })
  @IsString()
  @IsNotEmpty()
  item_name: string;

  @ApiProperty({ example: 'SKU-ACHINGA-400' })
  @IsString()
  @IsNotEmpty()
  sku: string;

  @ApiProperty({ example: 10, description: 'Packets per carton' })
  @IsNumber()
  @Min(0)
  packet_per_carton: number;

  @ApiProperty({ example: 20, description: 'Number of cartons' })
  @IsNumber()
  @Min(0)
  cartons: number;

  @ApiPropertyOptional({ example: 200, description: 'Total packets (optional)' })
  @IsNumber()
  @Min(0)
  @IsOptional()
  total_packets?: number;

  @ApiPropertyOptional({ example: 'PIECE' })
  @IsString()
  @IsOptional()
  unit?: string;
}

export class CreatePurchaseOrderDto {
  @ApiProperty({ example: 'MALTA-PO-2026-01', description: 'Unique PO Number' })
  @IsString()
  @IsNotEmpty()
  po_number: string;

  @ApiProperty({
    example: '2026-10-27T00:00:00.000Z',
    description: 'PO Issue Date (ISO format or YYYY-MM-DD)',
  })
  @IsString()
  @IsNotEmpty()
  po_date: string;

  @ApiPropertyOptional({
    example: '2026-11-15T00:00:00.000Z',
    description: 'Expected Shipping Date',
  })
  @IsString()
  @IsOptional()
  expected_shipping_date?: string;

  @ApiProperty({ example: 'cust-uuid-1', description: 'Customer ID' })
  @IsString()
  @IsNotEmpty()
  customer_id: string;

  @ApiProperty({ example: 'KDM TRADING, MALTA', description: 'Customer Name' })
  @IsString()
  @IsNotEmpty()
  customer_name: string;

  @ApiPropertyOptional({ example: 'Malta Industrial Zone' })
  @IsString()
  @IsOptional()
  customer_address?: string;

  @ApiPropertyOptional({ example: '+356 9912 3456' })
  @IsString()
  @IsOptional()
  customer_contact?: string;

  @ApiProperty({
    type: [PurchaseOrderItemDto],
    description: 'List of order items with cartons and packet details',
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PurchaseOrderItemDto)
  items: PurchaseOrderItemDto[];

  @ApiPropertyOptional({
    enum: PurchaseOrderStatus,
    example: PurchaseOrderStatus.CONFIRMED,
  })
  @IsEnum(PurchaseOrderStatus)
  @IsOptional()
  status?: PurchaseOrderStatus;

  @ApiPropertyOptional({ example: 'Fragile frozen cargo packaging' })
  @IsString()
  @IsOptional()
  notes?: string;
}

export class UpdatePurchaseOrderDto {
  @ApiPropertyOptional({ example: 'MALTA-PO-2026-01' })
  @IsString()
  @IsOptional()
  po_number?: string;

  @ApiPropertyOptional({ example: '2026-10-27T00:00:00.000Z' })
  @IsString()
  @IsOptional()
  po_date?: string;

  @ApiPropertyOptional({ example: '2026-11-15T00:00:00.000Z' })
  @IsString()
  @IsOptional()
  expected_shipping_date?: string;

  @ApiPropertyOptional({ example: 'cust-uuid-1' })
  @IsString()
  @IsOptional()
  customer_id?: string;

  @ApiPropertyOptional({ example: 'KDM TRADING, MALTA' })
  @IsString()
  @IsOptional()
  customer_name?: string;

  @ApiPropertyOptional({ example: 'Malta Industrial Zone' })
  @IsString()
  @IsOptional()
  customer_address?: string;

  @ApiPropertyOptional({ example: '+356 9912 3456' })
  @IsString()
  @IsOptional()
  customer_contact?: string;

  @ApiPropertyOptional({ type: [PurchaseOrderItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PurchaseOrderItemDto)
  @IsOptional()
  items?: PurchaseOrderItemDto[];

  @ApiPropertyOptional({
    enum: PurchaseOrderStatus,
    example: PurchaseOrderStatus.CONFIRMED,
  })
  @IsEnum(PurchaseOrderStatus)
  @IsOptional()
  status?: PurchaseOrderStatus;

  @ApiPropertyOptional({ example: 'Notes update' })
  @IsString()
  @IsOptional()
  notes?: string;
}
