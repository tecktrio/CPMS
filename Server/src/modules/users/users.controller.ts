import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @UseGuards(TenantGuard)
  async findAllInTenant(@CurrentTenant() tenantId: string) {
    return this.usersService.findAllInTenant(tenantId);
  }

  @Get(':id')
  async findOne(@Param('id') userId: string) {
    return this.usersService.findOne(userId);
  }
}

