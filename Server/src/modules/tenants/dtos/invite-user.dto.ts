import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class InviteUserDto {
  @ApiProperty({
    example: 'operator.jane@example.com',
    description: 'Email address of registered user to invite into tenant',
  })
  @IsEmail()
  @IsNotEmpty()
  email_address: string;

  @ApiProperty({
    example: ['dept-uuid-cold-storage-001'],
    description: 'List of Department UUIDs assigned to the invited user',
    type: [String],
  })
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  department_ids: string[];
}
