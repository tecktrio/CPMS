import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  Headers,
} from '@nestjs/common';
import { TenantsService } from './tenants.service';
import { CreateTenantDto } from './dtos/create-tenant.dto';
import { InviteUserDto } from './dtos/invite-user.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('tenants')
@UseGuards(JwtAuthGuard)
export class TenantsController {
  constructor(private readonly tenantsService: TenantsService) {}

  @Post()
  async createTenant(
    @CurrentUser('user_id') userId: string,
    @Body() dto: CreateTenantDto,
  ) {
    return this.tenantsService.createTenant(userId, dto);
  }

  @Get()
  async getUserTenants(@CurrentUser('user_id') userId: string) {
    return this.tenantsService.getUserTenants(userId);
  }

  @Get(':id')
  async getTenantById(
    @Param('id') tenantId: string,
    @CurrentUser('user_id') userId: string,
  ) {
    return this.tenantsService.getTenantById(tenantId, userId);
  }

  @Post('invite')
  async inviteUser(
    @Headers('x-tenant-id') tenantId: string,
    @CurrentUser('user_id') userId: string,
    @Body() dto: InviteUserDto,
  ) {
    return this.tenantsService.inviteUser(tenantId, userId, dto);
  }
}

