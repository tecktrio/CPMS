import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class SignInDto {
  @ApiProperty({
    example: 'johndoe or john.doe@example.com',
    description: 'Registered username or email address',
  })
  @IsString()
  @IsNotEmpty()
  email_address: string;

  @ApiProperty({
    example: 'SecurePass123!',
    description: 'Account password',
  })
  @IsString()
  @IsNotEmpty()
  password: string;
}
