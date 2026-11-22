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
      this.logger.log('Starting verification of global fixed departments...');
      const res = await this.migrateAllTenantsToFixedDepartments();
      this.logger.log(
        `Verification complete: ${res.tenantsMigrated} tenant(s) verified with 9 global fixed departments.`,
      );
    } catch (err: any) {
      this.logger.warn(
        `Global fixed departments verification deferred: ${err.message}`,
      );
    }
  }

  /**
   * Automatically seeds the 9 fixed global system departments if missing.
   * Departments are common to all tenants and do not contain tenant_id.
   */
  async seedFixedDepartments(tenantId?: string): Promise<DepartmentDocument[]> {
    const seededDepartments: DepartmentDocument[] = [];

    for (const fixed of FIXED_DEPARTMENTS) {
      let existing = await this.departmentModel.findOne({
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
          department_id: fixed.department_id,
          department_name: fixed.name,
          description: fixed.description,
          permission_ids: fixed.permission_ids,
          is_active: true,
        });
        await newDept.save();
        seededDepartments.push(newDept);
      }
    }

    // Ensure only the 9 fixed departments are active in the database
    const fixedDeptIds = seededDepartments.map((d) => d.department_id);
    await this.departmentModel.updateMany(
      {
        department_id: { $nin: fixedDeptIds },
      },
      {
        $set: { is_active: false },
      },
    );

    return seededDepartments;
  }

  /**
   * Migrates and ensures all existing tenants across the entire system use the 9 global fixed departments.
   */
  async migrateAllTenantsToFixedDepartments(): Promise<{
    tenantsMigrated: number;
    details: Array<{
      tenantId: string;
      companyName: string;
      departmentCount: number;
      membersMigrated: number;
    }>;
  }> {
    const fixedDepts = await this.seedFixedDepartments();
    const fixedDeptIds = fixedDepts.map((d) => d.department_id);
    const adminDept =
      fixedDepts.find(
        (d) => d.department_name.toLowerCase() === 'administrator',
      ) || fixedDepts[0];

    const tenants = await this.tenantModel.find({});
    const details = [];

    for (const tenant of tenants) {
      const memberships = await this.membershipModel.find({
        tenant_id: tenant.tenant_id,
      });
      let membersMigrated = 0;

      for (const mem of memberships) {
        const isTenantAdmin = tenant.admin_user_id === mem.user_id;

        if (isTenantAdmin) {
          mem.department_ids = fixedDeptIds;
          mem.is_active = true;
          await mem.save();
          membersMigrated++;
          continue;
        }

        const validIds = (mem.department_ids || []).filter((id) =>
          fixedDeptIds.includes(id),
        );
        if (validIds.length === 0) {
          validIds.push(adminDept.department_id);
        }
        mem.department_ids = validIds;
        mem.is_active = true;
        await mem.save();
        membersMigrated++;
      }

      if (tenant.admin_user_id) {
        await this.membershipModel.updateOne(
          {
            tenant_id: tenant.tenant_id,
            user_id: tenant.admin_user_id,
          },
          {
            $set: {
              department_ids: fixedDeptIds,
              is_active: true,
            },
          },
          { upsert: true },
        );
      }

      details.push({
        tenantId: tenant.tenant_id,
        companyName: tenant.company_name,
        departmentCount: fixedDepts.length,
        membersMigrated,
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

  async findAll(tenantId?: string) {
    const activeFixedCount = await this.departmentModel.countDocuments({
      is_active: true,
    });

    if (activeFixedCount < FIXED_DEPARTMENTS.length) {
      await this.seedFixedDepartments();
    }

    return this.departmentModel
      .find({
        is_active: true,
      })
      .sort({ department_name: 1 });
  }

  async findByIds(arg1: string | string[], arg2?: string[]) {
    const departmentIds = Array.isArray(arg1) ? arg1 : (arg2 || []);
    return this.departmentModel
      .find({
        department_id: { $in: departmentIds },
        is_active: true,
      })
      .sort({ department_name: 1 });
  }

  async findOne(arg1: string, arg2?: string) {
    const departmentId = arg2 || arg1;
    const department = await this.departmentModel.findOne({
      department_id: departmentId,
      is_active: true,
    });

    if (!department) {
      throw new NotFoundException(
        `Department with ID "${departmentId}" not found`,
      );
    }

    return department;
  }

  async update(arg1: string, arg2: string | UpdateDepartmentDto, arg3?: UpdateDepartmentDto) {
    const departmentId = typeof arg2 === 'string' ? arg2 : arg1;
    const dto = (arg3 || (typeof arg2 !== 'string' ? arg2 : {})) as UpdateDepartmentDto;
    const department = await this.findOne(departmentId);

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

  async delete(arg1: string, arg2?: string) {
    const departmentId = arg2 || arg1;
    const department = await this.findOne(departmentId);

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
   * Validates that all supplied department IDs exist and are active in the global fixed departments.
   */
  async validateDepartmentsExist(
    arg1: string | string[],
    arg2?: string[],
  ): Promise<DepartmentDocument[]> {
    const departmentIds = Array.isArray(arg1) ? arg1 : (arg2 || []);

    if (!departmentIds || departmentIds.length === 0) {
      throw new BadRequestException(
        'At least one valid department ID must be selected when adding a user to a tenant organization.',
      );
    }

    const matchedDepartments = await this.departmentModel.find({
      department_id: { $in: departmentIds },
      is_active: true,
    });

    const foundIdSet = new Set(matchedDepartments.map((d) => d.department_id));
    const missingIds = departmentIds.filter((id) => !foundIdSet.has(id));

    if (missingIds.length > 0) {
      throw new BadRequestException(
        `Invalid or inactive department ID(s): ${missingIds.join(
          ', ',
        )}. Please select existing active fixed departments.`,
      );
    }

    return matchedDepartments;
  }
}
