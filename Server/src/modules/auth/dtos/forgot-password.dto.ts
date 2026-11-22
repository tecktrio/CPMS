import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString } from 'class-validator';

export class ForgotPasswordDto {
  @ApiPropertyOptional({
    description: 'Registered username of the account to reset password for',
    example: 'johndoe',
  })
  @IsOptional()
  @IsString()
  user_name?: string;

  @ApiPropertyOptional({
    description: 'Registered user email address (fallback)',
    example: 'john.doe@example.com',
  })
  @IsOptional()
  @IsEmail({}, { message: 'Must be a valid email address' })
  email_address?: string;
}
