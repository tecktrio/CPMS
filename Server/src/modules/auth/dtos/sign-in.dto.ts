import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SignInDto {
  @ApiPropertyOptional({
    example: 'johndoe',
    description: 'Unique global username',
  })
  @IsString()
  @IsOptional()
  user_name?: string;

  @ApiPropertyOptional({
    example: 'johndoe or john.doe@example.com',
    description: 'Registered username or email address',
  })
  @IsString()
  @IsOptional()
  email_address?: string;

  @ApiProperty({
    example: 'SecurePass123!',
    description: 'Account password',
  })
  @IsString()
  @IsNotEmpty()
  password: string;
}
