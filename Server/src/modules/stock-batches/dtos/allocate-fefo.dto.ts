import { IsNotEmpty, IsNumber, IsString, Min } from 'class-validator';

export class AllocateFefoDto {
  @IsString()
  @IsNotEmpty()
  item_id: string;

  @IsNumber()
  @Min(0.01)
  requested_quantity: number;
}

