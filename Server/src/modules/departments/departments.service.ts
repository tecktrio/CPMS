import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  ForbiddenException,
  OnModuleInit,
  Logger,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  Department,
  DepartmentDocument,
} from '../../database/schemas/department.schema';
import {
  Tenant,
  TenantDocument,
} from '../../database/schemas/tenant.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';
import { PermissionsService } from '../permissions/permissions.service';
import { CreateDepartmentDto } from './dtos/create-department.dto';
import { UpdateDepartmentDto } from './dtos/update-department.dto';
import { FIXED_DEPARTMENTS } from './departments.constants';

@Injectable()
export class DepartmentsService implements OnModuleInit {
  private readonly logger = new Logger(DepartmentsService.name);

  constructor(
    @InjectModel(Department.name)
    private readonly departmentModel: Model<DepartmentDocument>,
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
    private readonly permissionsService: PermissionsService,
  ) {}

  async onModuleInit() {
    try {
      this.logger.log('Starting automated migration of existing tenants to fixed departments...');
      const res = await this.migrateAllTenantsToFixedDepartments();
      this.logger.log(
        `Migration complete: ${res.tenantsMigrated} tenant(s) verified/updated to 9 fixed departments.`,
      );
    } catch (err: any) {
      this.logger.warn(
        `Automated fixed departments migration deferred: ${err.message}`,
      );
    }
  }

  /**
   * Automatically seeds the 9 fixed system departments for a tenant.
   * If any already exist, their permission set and description are updated/synced.
   * Also deactivates any obsolete non-fixed departments.
   */
  async seedFixedDepartments(tenantId: string): Promise<DepartmentDocument[]> {
    const seededDepartments: DepartmentDocument[] = [];

    for (const fixed of FIXED_DEPARTMENTS) {
      const existing = await this.departmentModel.findOne({
        tenant_id: tenantId,
        department_name: { $regex: new RegExp(`^${fixed.name}$`, 'i') },
      });

      if (existing) {
        existing.department_name = fixed.name;
        existing.permission_ids = fixed.permission_ids;
        existing.description = fixed.description;
        existing.is_active = true;
        await existing.save();
        seededDepartments.push(existing);
      } else {
        const newDept = new this.departmentModel({
          department_id: uuidv4(),
          tenant_id: tenantId,
          department_name: fixed.name,
          description: fixed.description,
          permission_ids: fixed.permission_ids,
          is_active: true,
        });
        await newDept.save();
        seededDepartments.push(newDept);
      }
    }

    // Deactivate any legacy custom departments that are not among the 9 fixed presets
    const fixedDeptIds = seededDepartments.map((d) => d.department_id);
    await this.departmentModel.updateMany(
      {
        tenant_id: tenantId,
        department_id: { $nin: fixedDeptIds },
      },
      {
        $set: { is_active: false },
      },
    );

    return seededDepartments;
  }

  /**
   * Migrates and ensures all existing tenants across the entire system have the 9 fixed departments
   * and that their administrators are granted access to all fixed departments.
   */
  async migrateAllTenantsToFixedDepartments(): Promise<{
    tenantsMigrated: number;
    details: Array<{ tenantId: string; companyName: string; departmentCount: number }>;
  }> {
    const tenants = await this.tenantModel.find({});
    const details = [];

    for (const tenant of tenants) {
      const fixedDepts = await this.seedFixedDepartments(tenant.tenant_id);
      const fixedDeptIds = fixedDepts.map((d) => d.department_id);

      // Ensure the tenant admin has all 9 fixed departments
      if (tenant.admin_user_id) {
        await this.membershipModel.updateOne(
          {
            tenant_id: tenant.tenant_id,
            user_id: tenant.admin_user_id,
          },
          {
            $addToSet: { department_ids: { $each: fixedDeptIds } },
          },
        );
      }

      details.push({
        tenantId: tenant.tenant_id,
        companyName: tenant.company_name,
        departmentCount: fixedDepts.length,
      });
    }

    return {
      tenantsMigrated: tenants.length,
      details,
    };
  }

  async create(tenantId: string, dto: CreateDepartmentDto) {
    throw new ForbiddenException(
      'Custom departments cannot be created. Departments in this system are fixed presets (Administrator, Sales, Store Room, Production Manager, Supervisor, QC, Packer, Export, Accounts).',
    );
  }

  async findAll(tenantId: string) {
    // Proactively verify that the tenant has all 9 fixed system departments active
    const activeFixedCount = await this.departmentModel.countDocuments({
      tenant_id: tenantId,
      department_name: {
        $in: FIXED_DEPARTMENTS.map((f) => new RegExp(`^${f.name}$`, 'i')),
      },
      is_active: true,
    });

    if (activeFixedCount < FIXED_DEPARTMENTS.length) {
      await this.seedFixedDepartments(tenantId);
    }

    return this.departmentModel
      .find({
        tenant_id: tenantId,
        is_active: true,
      })
      .sort({ department_name: 1 });
  }

  async findByIds(tenantId: string, departmentIds: string[]) {
    return this.departmentModel
      .find({
        tenant_id: tenantId,
        department_id: { $in: departmentIds },
        is_active: true,
      })
      .sort({ department_name: 1 });
  }

  async findOne(tenantId: string, departmentId: string) {
    const department = await this.departmentModel.findOne({
      tenant_id: tenantId,
      department_id: departmentId,
      is_active: true,
    });

    if (!department) {
      throw new NotFoundException(
        `Department with ID "${departmentId}" not found in this organization`,
      );
    }

    return department;
  }

  async update(tenantId: string, departmentId: string, dto: UpdateDepartmentDto) {
    const department = await this.findOne(tenantId, departmentId);

    // Prevent altering fixed department permissions or core identity
    const isFixed = FIXED_DEPARTMENTS.some(
      (f) => f.name.toLowerCase() === department.department_name.toLowerCase(),
    );

    if (isFixed && dto.permission_ids !== undefined) {
      throw new ForbiddenException(
        'Permission sets for fixed preset departments are immutable and managed by the system.',
      );
    }

    if (dto.description !== undefined) {
      department.description = dto.description.trim();
    }

    await department.save();
    return department;
  }

  async delete(tenantId: string, departmentId: string) {
    const department = await this.findOne(tenantId, departmentId);

    const isFixed = FIXED_DEPARTMENTS.some(
      (f) => f.name.toLowerCase() === department.department_name.toLowerCase(),
    );
    if (isFixed) {
      throw new ForbiddenException(
        'Fixed system departments cannot be deleted or deactivated.',
      );
    }

    department.is_active = false;
    await department.save();

    return {
      message: `Department "${department.department_name}" deactivated successfully`,
      department_id: departmentId,
    };
  }

  /**
   * Validates that all supplied department IDs exist, belong to this tenant, and are active.
   * Used when adding a user to ensure only valid tenant departments are assigned.
   */
  async validateDepartmentsExist(
    tenantId: string,
    departmentIds: string[],
  ): Promise<DepartmentDocument[]> {
    if (!departmentIds || departmentIds.length === 0) {
      throw new BadRequestException(
        'At least one valid department ID must be selected when adding a user to a tenant organization.',
      );
    }

    const matchedDepartments = await this.departmentModel.find({
      tenant_id: tenantId,
      department_id: { $in: departmentIds },
      is_active: true,
    });

    const foundIdSet = new Set(matchedDepartments.map((d) => d.department_id));
    const missingIds = departmentIds.filter((id) => !foundIdSet.has(id));

    if (missingIds.length > 0) {
      throw new BadRequestException(
        `Invalid or inactive department ID(s) for this tenant: ${missingIds.join(
          ', ',
        )}. Please select existing active departments from this organization.`,
      );
    }

    return matchedDepartments;
  }
}

