import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class UpdateStoreRoomDto {
  @IsString()
  @IsOptional()
  room_code?: string;

  @IsString()
  @IsOptional()
  room_name?: string;

  @IsNumber()
  @IsOptional()
  temperature?: number;

  @IsNumber()
  @Min(1)
  @IsOptional()
  total_capacity_units?: number;

  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}

