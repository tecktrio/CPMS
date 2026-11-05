import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
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

@Injectable()
export class DepartmentsService {
  constructor(
    @InjectModel(Department.name)
    private readonly departmentModel: Model<DepartmentDocument>,
    private readonly permissionsService: PermissionsService,
  ) {}

  async create(tenantId: string, dto: CreateDepartmentDto) {
    const trimmedName = dto.department_name.trim();

    // Enforce unique department name per tenant
    const existing = await this.departmentModel.findOne({
      tenant_id: tenantId,
      department_name: { $regex: new RegExp(`^${trimmedName}$`, 'i') },
      is_active: true,
    });

    if (existing) {
      throw new ConflictException(
        `Department with name "${trimmedName}" already exists in this organization`,
      );
    }

    // Validate that provided permissions exist in system catalogue
    await this.permissionsService.validatePermissionIds(dto.permission_ids);

    const newDepartment = new this.departmentModel({
      department_id: uuidv4(),
      tenant_id: tenantId,
      department_name: trimmedName,
      description: dto.description?.trim() || '',
      permission_ids: dto.permission_ids,
      is_active: true,
    });

    await newDepartment.save();
    return newDepartment;
  }

  async findAll(tenantId: string) {
    return this.departmentModel
      .find({
        tenant_id: tenantId,
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

    if (dto.department_name) {
      const trimmedName = dto.department_name.trim();
      const duplicate = await this.departmentModel.findOne({
        tenant_id: tenantId,
        department_name: { $regex: new RegExp(`^${trimmedName}$`, 'i') },
        department_id: { $ne: departmentId },
        is_active: true,
      });

      if (duplicate) {
        throw new ConflictException(
          `Another department with name "${trimmedName}" already exists in this organization`,
        );
      }
      department.department_name = trimmedName;
    }

    if (dto.description !== undefined) {
      department.description = dto.description.trim();
    }

    if (dto.permission_ids !== undefined) {
      await this.permissionsService.validatePermissionIds(dto.permission_ids);
      department.permission_ids = dto.permission_ids;
    }

    if (dto.is_active !== undefined) {
      department.is_active = dto.is_active;
    }

    await department.save();
    return department;
  }

  async delete(tenantId: string, departmentId: string) {
    const department = await this.findOne(tenantId, departmentId);
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

