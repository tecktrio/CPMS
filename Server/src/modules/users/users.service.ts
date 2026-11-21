import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Tenant, TenantDocument } from '../../database/schemas/tenant.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    private readonly storageService: StorageService,
  ) {}

  async searchGlobalUsers(query: string, currentTenantId: string) {
    const trimmed = (query || '').trim();
    if (!trimmed || trimmed.length < 1) {
      return [];
    }

    // Escape regex special chars safely
    const escaped = trimmed.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(escaped, 'i');

    const users = await this.userModel
      .find({
        $or: [
          { user_name: regex },
          { email_address: regex },
          { full_name: regex },
        ],
      })
      .limit(20);

    const userIds = users.map((u) => u.user_id);

    // Find all memberships of these users across all tenants
    const memberships = await this.membershipModel.find({
      user_id: { $in: userIds },
      is_active: true,
    });

    // Find if any of these users own any active tenant
    const ownedTenants = await this.tenantModel.find({
      admin_user_id: { $in: userIds },
      is_active: true,
    });

    // Also get tenant details for other tenants so we can display their company name
    const allTenantIds = Array.from(
      new Set([
        ...memberships.map((m) => m.tenant_id),
        ...ownedTenants.map((t) => t.tenant_id),
      ]),
    );
    const tenants = await this.tenantModel.find({
      tenant_id: { $in: allTenantIds },
    });
    const tenantMap = new Map(tenants.map((t) => [t.tenant_id, t.company_name]));

    return users.map((u) => {
      const currentMembership = memberships.find(
        (m) => m.user_id === u.user_id && m.tenant_id === currentTenantId,
      );
      const otherMembership = memberships.find(
        (m) => m.user_id === u.user_id && m.tenant_id !== currentTenantId,
      );
      const ownedOther = ownedTenants.find(
        (t) => t.admin_user_id === u.user_id && t.tenant_id !== currentTenantId,
      );
      const isOwnerCurrent = ownedTenants.some(
        (t) => t.admin_user_id === u.user_id && t.tenant_id === currentTenantId,
      );

      const isInCurrentTenant = Boolean(currentMembership || isOwnerCurrent);
      const otherTenantId = otherMembership?.tenant_id || ownedOther?.tenant_id;
      const otherTenantName = otherTenantId
        ? tenantMap.get(otherTenantId) || 'Other Organization'
        : null;
      const isInOtherTenant = Boolean(otherTenantId);

      return {
        user_id: u.user_id,
        user_name: u.user_name || '',
        full_name: u.full_name || '',
        email_address: u.email_address || '',
        avatar_url: u.avatar_url || null,
        is_in_current_tenant: isInCurrentTenant,
        is_in_other_tenant: isInOtherTenant,
        other_tenant_name: otherTenantName,
        is_available: !isInCurrentTenant && !isInOtherTenant,
      };
    });
  }

  async findAllInTenant(tenantId: string) {
    const memberships = await this.membershipModel.find({
      tenant_id: tenantId,
      is_active: true,
    });

    const userIds = memberships.map((m) => m.user_id);
    const users = await this.userModel.find({ user_id: { $in: userIds } });

    return users.map((u) => {
      const mem = memberships.find((m) => m.user_id === u.user_id);
      return {
        user_id: u.user_id,
        user_name: u.user_name,
        full_name: u.full_name,
        email_address: u.email_address,
        avatar_url: u.avatar_url || null,
        department_ids: mem?.department_ids || [],
        account_status: u.account_status,
      };
    });
  }

  async findOne(userId: string) {
    const user = await this.userModel.findOne({ user_id: userId });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async updateAvatar(userId: string, avatarUrl: string | null) {
    const user = await this.userModel.findOne({ user_id: userId });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Delete old avatar from S3 if replacing with a new one or removing
    if (user.avatar_url && user.avatar_url !== avatarUrl) {
      await this.storageService.deleteFile(user.avatar_url);
    }

    user.avatar_url = avatarUrl;
    await user.save();

    return {
      user_id: user.user_id,
      full_name: user.full_name,
      email_address: user.email_address,
      avatar_url: user.avatar_url,
    };
  }

  async removeAvatar(userId: string) {
    return this.updateAvatar(userId, null);
  }

  async updateProfile(
    userId: string,
    data: { full_name?: string; phone_number?: string },
  ) {
    const user = await this.userModel.findOne({ user_id: userId });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (data.full_name !== undefined && data.full_name.trim().length > 0) {
      user.full_name = data.full_name.trim();
    }
    if (data.phone_number !== undefined) {
      user.phone_number = data.phone_number ? data.phone_number.trim() : null;
    }

    await user.save();

    return {
      user_id: user.user_id,
      full_name: user.full_name,
      email_address: user.email_address,
      avatar_url: user.avatar_url || null,
      phone_number: user.phone_number || null,
      department_id: user.department_id,
      account_status: user.account_status,
    };
  }
}

