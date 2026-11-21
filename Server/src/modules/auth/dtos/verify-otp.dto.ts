import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';

export class VerifyOtpDto {
  @ApiPropertyOptional({
    example: 'johndoe',
    description: 'Unique global username',
  })
  @IsString()
  @IsOptional()
  user_name?: string;

  @ApiPropertyOptional({
    example: 'john.doe@example.com',
    description: 'Email address where OTP was dispatched',
  })
  @IsString()
  @IsOptional()
  email_address?: string;

  @ApiProperty({
    example: '123456',
    description: '6-digit OTP verification code received via email',
  })
  @IsString()
  @Length(6, 6, { message: 'OTP must be exactly 6 digits' })
  otp_code: string;
}
