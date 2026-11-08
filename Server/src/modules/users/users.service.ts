import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
  ) {}

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

  async updateAvatar(userId: string, avatarUrl: string) {
    const user = await this.userModel.findOneAndUpdate(
      { user_id: userId },
      { $set: { avatar_url: avatarUrl } },
      { new: true },
    );
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return {
      user_id: user.user_id,
      full_name: user.full_name,
      email_address: user.email_address,
      avatar_url: user.avatar_url,
    };
  }
}

