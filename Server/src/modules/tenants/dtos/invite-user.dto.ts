import { IsArray, IsEmail, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class InviteUserDto {
  @IsEmail()
  @IsNotEmpty()
  email_address: string;

  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  department_ids: string[];
}

