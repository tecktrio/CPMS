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
}

