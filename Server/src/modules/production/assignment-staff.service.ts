import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Department, DepartmentDocument } from '../../database/schemas/department.schema';
import { TenantMembership, TenantMembershipDocument } from '../../database/schemas/tenant-membership.schema';
import { User, UserAccountStatus, UserDocument } from '../../database/schemas/user.schema';
import { QUALITY_DEPARTMENT_NAME } from '../departments/departments.constants';

@Injectable()
export class AssignmentStaffService {
  constructor(
    @InjectModel(Department.name) private readonly departments: Model<DepartmentDocument>,
    @InjectModel(TenantMembership.name) private readonly memberships: Model<TenantMembershipDocument>,
    @InjectModel(User.name) private readonly users: Model<UserDocument>,
  ) {}

  async list(tenantId: string, departmentName: 'Supervisor' | 'QC', userId?: string) {
    const departments = await this.departments.find({
      department_name: departmentName === 'QC' ? QUALITY_DEPARTMENT_NAME : departmentName,
      $or: [{ tenant_id: tenantId }, { tenant_id: null }],
      is_active: true,
    });
    const memberships = await this.memberships.find({
      tenant_id: tenantId,
      is_active: true,
      department_ids: { $in: departments.map((department) => department.department_id) },
      ...(userId && { user_id: userId }),
    });
    const users = await this.users.find({
      user_id: { $in: memberships.map((membership) => membership.user_id) },
      account_status: { $nin: [UserAccountStatus.INACTIVE, UserAccountStatus.SUSPENDED] },
    }).select('user_id full_name email_address');
    return users.map((user) => ({
      user_id: user.user_id,
      name: user.full_name || user.email_address,
    }));
  }

  async requireMember(tenantId: string, departmentName: 'Supervisor' | 'QC', userId: string) {
    const [member] = await this.list(tenantId, departmentName, userId);
    if (!member) throw new BadRequestException('Choose a user in the requested department in this tenant.');
    return member;
  }
}
