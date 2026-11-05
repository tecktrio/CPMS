import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({
    example: 'john.doe@example.com',
    description: 'Email address where OTP was dispatched',
  })
  @IsEmail()
  @IsNotEmpty()
  email_address: string;

  @ApiProperty({
    example: '123456',
    description: '6-digit OTP verification code received via email',
  })
  @IsString()
  @Length(6, 6, { message: 'OTP must be exactly 6 digits' })
  otp_code: string;
}
