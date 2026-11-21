import { ApiProperty } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  Matches,
  MinLength,
} from 'class-validator';

export class SignUpDto {
  @ApiProperty({
    example: 'johndoe',
    description: 'Unique global username (letters, numbers, underscore, 3-30 chars)',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(3, { message: 'Username must be at least 3 characters long' })
  @Matches(/^[a-zA-Z0-9_.-]+$/, {
    message:
      'Username can only contain alphanumeric characters, underscores, dots, or dashes',
  })
  user_name: string;

  @ApiProperty({ example: 'John Doe', description: "User's full name" })
  @IsString()
  @IsNotEmpty()
  full_name: string;

  @ApiProperty({
    example: 'john.doe@example.com',
    description: 'Email address (can be used across multiple tenant accounts)',
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
