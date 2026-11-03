import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateStoreRoomDto {
  @IsString()
  @IsNotEmpty()
  room_code: string;

  @IsString()
  @IsNotEmpty()
  room_name: string;

  @IsNumber()
  @IsNotEmpty()
  temperature: number; // e.g. -18.0 °C

  @IsNumber()
  @Min(1)
  total_capacity_units: number;

  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}

