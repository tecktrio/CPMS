import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class SignUpDto {
  @ApiProperty({ example: 'John Doe', description: "User's full name" })
  @IsString()
  @IsNotEmpty()
  full_name: string;

  @ApiProperty({
    example: 'john.doe@example.com',
    description: 'Unique login email address',
  })
  @IsEmail()
  @IsNotEmpty()
  email_address: string;

  @ApiProperty({
    example: 'SecurePass123!',
    description: 'Account password (minimum 6 characters)',
  })
  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters long' })
  password: string;
}
