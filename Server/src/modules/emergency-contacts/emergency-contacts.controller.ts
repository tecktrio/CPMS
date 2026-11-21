import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { EmergencyContactsService } from './emergency-contacts.service';
import { CreateEmergencyContactDto } from './dtos/create-emergency-contact.dto';
import { UpdateEmergencyContactDto } from './dtos/update-emergency-contact.dto';

@ApiTags('Emergency Contacts')
@ApiBearerAuth()
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant UUID',
  required: true,
})
@UseGuards(JwtAuthGuard, TenantGuard)
@Controller('emergency-contacts')
export class EmergencyContactsController {
  constructor(
    private readonly emergencyContactsService: EmergencyContactsService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'List active emergency contacts for current tenant',
    description:
      'Accessible to all organization members to view direct emergency hotlines and personnel.',
  })
  @ApiResponse({
    status: 200,
    description: 'Array of active emergency contacts',
  })
  async findAll(@CurrentTenant() tenantId: string) {
    return this.emergencyContactsService.findAll(tenantId);
  }

  @Post()
  @ApiOperation({
    summary: 'Create emergency contact (Administrator department only)',
    description:
      'Allows staff users in the Administrator department to add new emergency contacts.',
  })
  @ApiResponse({
    status: 201,
    description: 'Emergency contact created successfully',
  })
  async create(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Req() req: any,
    @Body() dto: CreateEmergencyContactDto,
  ) {
    const departmentIds = req.tenant_membership?.department_ids || [];
    return this.emergencyContactsService.create(
      tenantId,
      userId,
      departmentIds,
      dto,
    );
  }

  @Put(':id')
  @ApiOperation({
    summary: 'Update emergency contact (Administrator department only)',
    description:
      'Allows staff users in the Administrator department to update emergency contact details.',
  })
  @ApiResponse({
    status: 200,
    description: 'Emergency contact updated successfully',
  })
  async update(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Req() req: any,
    @Param('id') contactId: string,
    @Body() dto: UpdateEmergencyContactDto,
  ) {
    const departmentIds = req.tenant_membership?.department_ids || [];
    return this.emergencyContactsService.update(
      tenantId,
      userId,
      departmentIds,
      contactId,
      dto,
    );
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Delete/deactivate emergency contact (Administrator department only)',
    description:
      'Allows staff users in the Administrator department to remove an emergency contact.',
  })
  @ApiResponse({
    status: 200,
    description: 'Emergency contact removed successfully',
  })
  async delete(
    @CurrentTenant() tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Req() req: any,
    @Param('id') contactId: string,
  ) {
    const departmentIds = req.tenant_membership?.department_ids || [];
    return this.emergencyContactsService.delete(
      tenantId,
      userId,
      departmentIds,
      contactId,
    );
  }
}

