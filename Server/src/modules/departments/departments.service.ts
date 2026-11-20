import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  Department,
  DepartmentDocument,
} from '../../database/schemas/department.schema';
import { PermissionsService } from '../permissions/permissions.service';
import { CreateDepartmentDto } from './dtos/create-department.dto';
import { UpdateDepartmentDto } from './dtos/update-department.dto';
import { FIXED_DEPARTMENTS } from './departments.constants';

@Injectable()
export class DepartmentsService {
  constructor(
    @InjectModel(Department.name)
    private readonly departmentModel: Model<DepartmentDocument>,
    private readonly permissionsService: PermissionsService,
  ) {}

  /**
   * Automatically seeds the 9 fixed system departments for a tenant.
   * If any already exist, their permission set and description are updated/synced.
   */
  async seedFixedDepartments(tenantId: string): Promise<DepartmentDocument[]> {
    const seededDepartments: DepartmentDocument[] = [];

    for (const fixed of FIXED_DEPARTMENTS) {
      const existing = await this.departmentModel.findOne({
        tenant_id: tenantId,
        department_name: { $regex: new RegExp(`^${fixed.name}$`, 'i') },
      });

      if (existing) {
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

    return seededDepartments;
  }

  async create(tenantId: string, dto: CreateDepartmentDto) {
    throw new ForbiddenException(
      'Custom departments cannot be created. Departments in this system are fixed presets (Administrator, Sales, Store Room, Production Manager, Supervisor, QC, Packer, Export, Accounts).',
    );
  }

  async findAll(tenantId: string) {
    // Check if fixed departments are seeded; if not, auto-seed them
    const count = await this.departmentModel.countDocuments({
      tenant_id: tenantId,
      is_active: true,
    });
    if (count === 0) {
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

