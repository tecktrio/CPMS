import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Length, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({
    description: 'Registered user email address',
    example: 'john.doe@example.com',
  })
  @IsEmail({}, { message: 'Must be a valid email address' })
  @IsNotEmpty({ message: 'Email address is required' })
  email_address: string;

  @ApiProperty({
    description: '6-digit OTP code received via email',
    example: '123456',
  })
  @IsString()
  @Length(6, 6, { message: 'OTP code must be exactly 6 digits' })
  @IsNotEmpty({ message: 'OTP code is required' })
  otp_code: string;

  @ApiProperty({
    description: 'New password for the account (minimum 6 characters)',
    example: 'NewSecurePassword123!',
    minLength: 6,
  })
  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters long' })
  @IsNotEmpty({ message: 'New password is required' })
  new_password: string;
}

