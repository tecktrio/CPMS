import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import { Tenant, TenantDocument } from '../../database/schemas/tenant.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { CreateTenantDto } from './dtos/create-tenant.dto';
import { InviteUserDto } from './dtos/invite-user.dto';

@Injectable()
export class TenantsService {
  constructor(
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
  ) {}

  async createTenant(userId: string, dto: CreateTenantDto) {
    const tenantId = uuidv4();

    const newTenant = new this.tenantModel({
      tenant_id: tenantId,
      company_name: dto.company_name.trim(),
      admin_user_id: userId,
      is_active: true,
    });

    await newTenant.save();

    // Automatically establish tenant membership for the creator as admin
    const membership = new this.membershipModel({
      membership_id: uuidv4(),
      user_id: userId,
      tenant_id: tenantId,
      department_ids: [],
      is_active: true,
    });

    await membership.save();

    return {
      message: 'Tenant created successfully',
      tenant: newTenant,
    };
  }

  async getUserTenants(userId: string) {
    const memberships = await this.membershipModel.find({
      user_id: userId,
      is_active: true,
    });

    const tenantIds = memberships.map((m) => m.tenant_id);

    const tenants = await this.tenantModel.find({
      tenant_id: { $in: tenantIds },
      is_active: true,
    });

    return tenants.map((tenant) => {
      const membership = memberships.find((m) => m.tenant_id === tenant.tenant_id);
      return {
        tenant_id: tenant.tenant_id,
        company_name: tenant.company_name,
        admin_user_id: tenant.admin_user_id,
        is_admin: tenant.admin_user_id === userId,
        department_ids: membership?.department_ids || [],
        created_at: (tenant as any).created_at,
      };
    });
  }

  async getTenantById(tenantId: string, userId: string) {
    const tenant = await this.tenantModel.findOne({
      tenant_id: tenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant not found');
    }

    const membership = await this.membershipModel.findOne({
      user_id: userId,
      tenant_id: tenantId,
      is_active: true,
    });

    if (!membership) {
      throw new ForbiddenException('Access denied to this tenant');
    }

    return {
      tenant_id: tenant.tenant_id,
      company_name: tenant.company_name,
      admin_user_id: tenant.admin_user_id,
      is_admin: tenant.admin_user_id === userId,
      department_ids: membership.department_ids,
    };
  }

  async inviteUser(tenantId: string, requestingUserId: string, dto: InviteUserDto) {
    const tenant = await this.tenantModel.findOne({
      tenant_id: tenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant not found');
    }

    if (tenant.admin_user_id !== requestingUserId) {
      throw new ForbiddenException(
        'Only the Tenant Admin can invite users to this organization',
      );
    }

    const targetUser = await this.userModel.findOne({
      email_address: dto.email_address.toLowerCase(),
    });

    if (!targetUser) {
      throw new NotFoundException(
        'User with this email is not registered in the system yet. Please ask them to register first.',
      );
    }

    const existingMembership = await this.membershipModel.findOne({
      user_id: targetUser.user_id,
      tenant_id: tenantId,
    });

    if (existingMembership) {
      if (existingMembership.is_active) {
        throw new ConflictException('User is already a member of this tenant');
      }
      existingMembership.is_active = true;
      existingMembership.department_ids = dto.department_ids;
      await existingMembership.save();
      return {
        message: 'User membership re-activated successfully',
        membership: existingMembership,
      };
    }

    const newMembership = new this.membershipModel({
      membership_id: uuidv4(),
      user_id: targetUser.user_id,
      tenant_id: tenantId,
      department_ids: dto.department_ids,
      is_active: true,
    });

    await newMembership.save();

    return {
      message: 'User invited and assigned to department successfully',
      membership: newMembership,
    };
  }
}

