import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import * as bcrypt from 'bcrypt';
import { Tenant, TenantDocument } from '../../database/schemas/tenant.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';
import {
  User,
  UserDocument,
  UserAccountStatus,
} from '../../database/schemas/user.schema';
import { Item, ItemDocument } from '../../database/schemas/item.schema';
import {
  StoreRoom,
  StoreRoomDocument,
} from '../../database/schemas/store-room.schema';
import {
  StockBatch,
  StockBatchDocument,
} from '../../database/schemas/stock-batch.schema';
import {
  PurchaseOrder,
  PurchaseOrderDocument,
} from '../../database/schemas/purchase-order.schema';
import {
  Department,
  DepartmentDocument,
} from '../../database/schemas/department.schema';
import {
  Customer,
  CustomerDocument,
} from '../../database/schemas/customer.schema';
import {
  OtpRecord,
  OtpRecordDocument,
} from '../../database/schemas/otp-record.schema';
import { CreateTenantDto } from './dtos/create-tenant.dto';
import { InviteUserDto } from './dtos/invite-user.dto';
import { AddUserDto } from './dtos/add-user.dto';
import { UpdateTenantUserDto } from './dtos/update-tenant-user.dto';
import { DepartmentsService } from '../departments/departments.service';

@Injectable()
export class TenantsService {
  constructor(
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @InjectModel(Item.name)
    private readonly itemModel: Model<ItemDocument>,
    @InjectModel(StoreRoom.name)
    private readonly storeRoomModel: Model<StoreRoomDocument>,
    @InjectModel(StockBatch.name)
    private readonly stockBatchModel: Model<StockBatchDocument>,
    @InjectModel(PurchaseOrder.name)
    private readonly purchaseOrderModel: Model<PurchaseOrderDocument>,
    @InjectModel(Department.name)
    private readonly departmentModel: Model<DepartmentDocument>,
    @InjectModel(Customer.name)
    private readonly customerModel: Model<CustomerDocument>,
    @InjectModel(OtpRecord.name)
    private readonly otpRecordModel: Model<OtpRecordDocument>,
    private readonly departmentsService: DepartmentsService,
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

    // Automatically seed the 9 fixed preset departments for the new tenant
    const seededDepts = await this.departmentsService.seedFixedDepartments(tenantId);
    const allDeptIds = seededDepts.map((d) => d.department_id);

    // Automatically establish tenant membership for the creator as admin (all departments assigned)
    const membership = new this.membershipModel({
      membership_id: uuidv4(),
      user_id: userId,
      tenant_id: tenantId,
      department_ids: allDeptIds,
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
      $or: [
        { tenant_id: { $in: tenantIds } },
        { admin_user_id: userId },
      ],
      is_active: true,
    });

    return Promise.all(
      tenants.map(async (tenant) => {
        const isAdmin = tenant.admin_user_id === userId;
        const membership = memberships.find((m) => m.tenant_id === tenant.tenant_id);

        // When a user is Tenant Admin, they have access to all departments in the organization
        let departmentIds = membership?.department_ids || [];
        if (isAdmin) {
          const allDepts = await this.departmentsService.findAll(tenant.tenant_id);
          departmentIds = allDepts.map((d) => d.department_id);
        }

        return {
          tenant_id: tenant.tenant_id,
          company_name: tenant.company_name,
          admin_user_id: tenant.admin_user_id,
          is_admin: isAdmin,
          has_all_departments_access: isAdmin,
          department_ids: departmentIds,
          created_at: (tenant as any).created_at,
        };
      }),
    );
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

    const isAdmin = tenant.admin_user_id === userId;
    let departmentIds = membership.department_ids || [];
    let depts: any[] = [];
    let permissions: string[] = [];

    if (isAdmin) {
      depts = await this.departmentsService.findAll(tenantId);
      departmentIds = depts.map((d) => d.department_id);
      permissions = Array.from(
        new Set(depts.flatMap((d) => d.permission_ids || [])),
      );
    } else {
      depts = await this.departmentsService.findByIds(
        tenantId,
        departmentIds,
      );
      permissions = Array.from(
        new Set(depts.flatMap((d) => d.permission_ids || [])),
      );
    }

    return {
      tenant_id: tenant.tenant_id,
      company_name: tenant.company_name,
      admin_user_id: tenant.admin_user_id,
      is_admin: isAdmin,
      has_all_departments_access: isAdmin,
      department_ids: departmentIds,
      departments: depts,
      permissions,
    };
  }

  async getMyPermissions(tenantId: string, userId: string) {
    const tenant = await this.tenantModel.findOne({
      tenant_id: tenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant not found');
    }

    const isAdmin = tenant.admin_user_id === userId;

    if (isAdmin) {
      const allDepts = await this.departmentsService.findAll(tenantId);
      const allSystemPerms = [
        'permission.item.read',
        'permission.item.create',
        'permission.item.update',
        'permission.item.delete',
        'permission.item_category.manage',
        'permission.packaging_material.manage',
        'permission.storeroom.read',
        'permission.storeroom.create',
        'permission.storeroom.update',
        'permission.storeroom.delete',
        'permission.department.read',
        'permission.department.create',
        'permission.department.update',
        'permission.department.delete',
        'permission.user.read',
        'permission.user.add',
        'permission.user.update',
        'permission.user.delete',
        'permission.po.create',
        'permission.po.read',
        'permission.po.update',
        'permission.po.delete',
        'permission.batch.read',
        'permission.batch.create',
        'permission.batch.update',
        'permission.batch.deduct',
        'permission.production.read',
        'permission.production.create',
        'permission.production.update',
        'permission.production.delete',
        'permission.qc.read',
        'permission.qc.create',
        'permission.qc.update',
        'permission.packing.update',
        'permission.export.update',
      ];
      const permissions = Array.from(
        new Set([...allSystemPerms, ...allDepts.flatMap((d) => d.permission_ids || [])]),
      );
      return {
        tenant_id: tenantId,
        is_admin: true,
        has_all_departments_access: true,
        department_ids: allDepts.map((d) => d.department_id),
        departments: allDepts,
        permissions,
      };
    }

    const membership = await this.membershipModel.findOne({
      user_id: userId,
      tenant_id: tenantId,
      is_active: true,
    });

    if (!membership) {
      return {
        tenant_id: tenantId,
        is_admin: false,
        has_all_departments_access: false,
        department_ids: [],
        departments: [],
        permissions: [],
      };
    }

    const depts = await this.departmentsService.findByIds(
      tenantId,
      membership.department_ids || [],
    );

    const permissionsSet = new Set<string>(
      depts.flatMap((d) => d.permission_ids || []),
    );

    // Auto-grant read permission if user has any other permission in that module
    for (const p of Array.from(permissionsSet)) {
      const parts = p.split('.');
      if (parts.length >= 3) {
        permissionsSet.add(`permission.${parts[1]}.read`);
      }
    }

    return {
      tenant_id: tenantId,
      is_admin: false,
      has_all_departments_access: false,
      department_ids: membership.department_ids || [],
      departments: depts,
      permissions: Array.from(permissionsSet),
    };
  }

  async addUserToTenant(
    headerTenantId: string | undefined,
    requestingUserId: string,
    dto: AddUserDto,
  ) {
    const effectiveTenantId = dto.tenant_id || headerTenantId;

    if (!effectiveTenantId) {
      throw new BadRequestException(
        'Tenant ID must be specified either in the request body (tenant_id) or via the X-Tenant-ID header',
      );
    }

    const tenant = await this.tenantModel.findOne({
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant organization not found');
    }

    if (tenant.admin_user_id !== requestingUserId) {
      throw new ForbiddenException(
        'Only the Tenant Admin can add users to this organization',
      );
    }

    // Validate that all specified departments exist, belong to this tenant, and are active
    await this.departmentsService.validateDepartmentsExist(
      effectiveTenantId,
      dto.department_ids,
    );

    const emailAddress = dto.email_address.toLowerCase().trim();

    // Find or automatically provision user profile
    let targetUser = await this.userModel.findOne({
      email_address: emailAddress,
    });

    if (!targetUser) {
      const salt = await bcrypt.genSalt(10);
      const temporaryHash = await bcrypt.hash(uuidv4(), salt);

      targetUser = new this.userModel({
        user_id: uuidv4(),
        full_name: emailAddress.split('@')[0],
        email_address: emailAddress,
        password_hash: temporaryHash,
        account_status: UserAccountStatus.PENDING_ACTIVATION,
      });

      await targetUser.save();
    }

    // Check existing membership in this tenant
    const existingMembership = await this.membershipModel.findOne({
      user_id: targetUser.user_id,
      tenant_id: effectiveTenantId,
    });

    if (existingMembership) {
      existingMembership.is_active = true;
      existingMembership.department_ids = dto.department_ids;
      await existingMembership.save();

      return {
        message: 'User already in tenant; department assignments updated successfully',
        membership: existingMembership,
        user: {
          user_id: targetUser.user_id,
          email_address: targetUser.email_address,
          full_name: targetUser.full_name,
          account_status: targetUser.account_status,
        },
      };
    }

    const newMembership = new this.membershipModel({
      membership_id: uuidv4(),
      user_id: targetUser.user_id,
      tenant_id: effectiveTenantId,
      department_ids: dto.department_ids,
      is_active: true,
    });

    await newMembership.save();

    return {
      message: 'User added to tenant and assigned to departments successfully',
      membership: newMembership,
      user: {
        user_id: targetUser.user_id,
        email_address: targetUser.email_address,
        full_name: targetUser.full_name,
        account_status: targetUser.account_status,
      },
    };
  }

  async inviteUser(
    tenantId: string,
    requestingUserId: string,
    dto: InviteUserDto,
  ) {
    return this.addUserToTenant(tenantId, requestingUserId, {
      ...dto,
      tenant_id: tenantId,
    });
  }

  async updateTenantUser(
    headerTenantId: string | undefined,
    requestingUserId: string,
    targetUserId: string,
    dto: UpdateTenantUserDto,
  ) {
    const effectiveTenantId = dto.tenant_id || headerTenantId;

    if (!effectiveTenantId) {
      throw new BadRequestException(
        'Tenant ID must be specified either in the request body (tenant_id) or via the X-Tenant-ID header',
      );
    }

    const tenant = await this.tenantModel.findOne({
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant organization not found');
    }

    if (tenant.admin_user_id !== requestingUserId) {
      throw new ForbiddenException(
        'Only the Tenant Admin can update users in this organization',
      );
    }

    // Validate that all specified departments exist, belong to this tenant, and are active
    await this.departmentsService.validateDepartmentsExist(
      effectiveTenantId,
      dto.department_ids,
    );

    const membership = await this.membershipModel.findOne({
      user_id: targetUserId,
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!membership) {
      throw new NotFoundException(
        `Active membership for user "${targetUserId}" not found in this tenant organization`,
      );
    }

    membership.department_ids = dto.department_ids;
    await membership.save();

    const user = await this.userModel.findOne({ user_id: targetUserId });

    return {
      message: 'Tenant user department assignments updated successfully',
      membership,
      user: user
        ? {
            user_id: user.user_id,
            email_address: user.email_address,
            full_name: user.full_name,
            account_status: user.account_status,
          }
        : null,
    };
  }

  async removeUserFromTenant(
    headerTenantId: string | undefined,
    requestingUserId: string,
    targetUserId: string,
  ) {
    const effectiveTenantId = headerTenantId;

    if (!effectiveTenantId) {
      throw new BadRequestException(
        'Tenant ID must be specified via the X-Tenant-ID header',
      );
    }

    const tenant = await this.tenantModel.findOne({
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant organization not found');
    }

    if (tenant.admin_user_id !== requestingUserId) {
      throw new ForbiddenException(
        'Only the Tenant Admin can remove users from this organization',
      );
    }

    if (targetUserId === requestingUserId || targetUserId === tenant.admin_user_id) {
      throw new BadRequestException(
        'The Tenant Admin cannot be removed from their own organization. Please transfer admin rights first or delete the organization.',
      );
    }

    const membership = await this.membershipModel.findOne({
      user_id: targetUserId,
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!membership) {
      throw new NotFoundException(
        `Active membership for user "${targetUserId}" not found in this tenant organization`,
      );
    }

    membership.is_active = false;
    membership.department_ids = [];
    await membership.save();

    return {
      message: 'User removed from tenant organization successfully',
      user_id: targetUserId,
      tenant_id: effectiveTenantId,
    };
  }

  async removeUserFromDepartment(
    headerTenantId: string | undefined,
    requestingUserId: string,
    targetUserId: string,
    departmentId: string,
  ) {
    const effectiveTenantId = headerTenantId;

    if (!effectiveTenantId) {
      throw new BadRequestException(
        'Tenant ID must be specified via the X-Tenant-ID header',
      );
    }

    const tenant = await this.tenantModel.findOne({
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!tenant) {
      throw new NotFoundException('Tenant organization not found');
    }

    if (tenant.admin_user_id !== requestingUserId) {
      throw new ForbiddenException(
        'Only the Tenant Admin can modify department assignments in this organization',
      );
    }

    const membership = await this.membershipModel.findOne({
      user_id: targetUserId,
      tenant_id: effectiveTenantId,
      is_active: true,
    });

    if (!membership) {
      throw new NotFoundException(
        `Active membership for user "${targetUserId}" not found in this tenant organization`,
      );
    }

    if (!membership.department_ids.includes(departmentId)) {
      throw new NotFoundException(
        `User "${targetUserId}" is not assigned to department "${departmentId}" in this organization`,
      );
    }

    membership.department_ids = membership.department_ids.filter(
      (id) => id !== departmentId,
    );
    await membership.save();

    return {
      message: `User removed from department "${departmentId}" successfully`,
      membership,
    };
  }

  /**
   * Permanently deletes a tenant organization and all its connected records.
   * Only the tenant's admin user can execute this.
   */
  async deleteTenant(userId: string, tenantId: string) {
    const tenant = await this.tenantModel.findOne({ tenant_id: tenantId });
    if (!tenant) {
      throw new NotFoundException('Organization not found');
    }

    if (tenant.admin_user_id !== userId) {
      throw new ForbiddenException(
        'Only the Tenant Admin can delete this organization',
      );
    }

    // 1. Delete all resources scoped by tenant_id
    await Promise.all([
      this.itemModel.deleteMany({ tenant_id: tenantId }),
      this.storeRoomModel.deleteMany({ tenant_id: tenantId }),
      this.stockBatchModel.deleteMany({ tenant_id: tenantId }),
      this.purchaseOrderModel.deleteMany({ tenant_id: tenantId }),
      this.departmentModel.deleteMany({ tenant_id: tenantId }),
      this.customerModel.deleteMany({ tenant_id: tenantId }),
      this.membershipModel.deleteMany({ tenant_id: tenantId }),
      this.tenantModel.deleteOne({ tenant_id: tenantId }),
    ]);

    return {
      success: true,
      message: `Organization "${tenant.company_name}" and all connected data have been permanently deleted`,
      tenant_id: tenantId,
    };
  }
}

