import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsString, Min } from 'class-validator';

export class AllocateFefoDto {
  @ApiProperty({
    example: 'item-uuid-001',
    description: 'Item UUID to allocate',
  })
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @ApiProperty({
    example: 75.0,
    description: 'Target quantity requested for production or dispatch',
  })
  @IsNumber()
  @Min(0.01)
  requested_quantity: number;
}
