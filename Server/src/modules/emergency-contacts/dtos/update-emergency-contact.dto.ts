import { PartialType } from '@nestjs/swagger';
import { CreateEmergencyContactDto } from './create-emergency-contact.dto';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateEmergencyContactDto extends PartialType(
  CreateEmergencyContactDto,
) {
  @ApiPropertyOptional({
    example: true,
    description: 'Active status of emergency contact',
  })
  @IsBoolean()
  @IsOptional()
  is_active?: boolean;
}
