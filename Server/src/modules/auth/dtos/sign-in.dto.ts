import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class SignInDto {
  @IsEmail()
  @IsNotEmpty()
  email_address: string;

  @IsString()
  @IsNotEmpty()
  password: string;
}

