import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class CreateTenantDto {
  @ApiProperty({
    example: 'Cyan International Food Production Ltd',
    description: 'Commercial organization or company name',
  })
  @IsString()
  @IsNotEmpty()
  company_name: string;
}
