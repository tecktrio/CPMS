import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty } from 'class-validator';

export class FindUsernamesDto {
  @ApiProperty({
    description: 'Registered user email address to find associated usernames',
    example: 'john.doe@example.com',
  })
  @IsEmail({}, { message: 'Must be a valid email address' })
  @IsNotEmpty({ message: 'Email address is required' })
  email_address: string;
}

