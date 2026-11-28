import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { FIXED_DEPARTMENTS, PACKING_DEPARTMENT_NAME, QUALITY_DEPARTMENT_NAME } from '../../modules/departments/departments.constants';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  PERMISSIONS_KEY,
  REQUIRE_ANY_KEY,
} from '../decorators/require-permissions.decorator';
import {
  Tenant,
  TenantDocument,
} from '../../database/schemas/tenant.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';
import {
  Department,
  DepartmentDocument,
} from '../../database/schemas/department.schema';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
    @InjectModel(Department.name)
    private readonly departmentModel: Model<DepartmentDocument>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    const requireAnyPermissions = this.reflector.getAllAndOverride<string[]>(
      REQUIRE_ANY_KEY,
      [context.getHandler(), context.getClass()],
    );

    // If no specific permissions are decorated, allow access (TenantGuard already validated membership)
    if (
      (!requiredPermissions || requiredPermissions.length === 0) &&
      (!requireAnyPermissions || requireAnyPermissions.length === 0)
    ) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const tenantId = request.tenant_id || request.headers['x-tenant-id'];

    if (!user || !user.user_id) {
      throw new ForbiddenException('User must be authenticated');
    }

    if (!tenantId) {
      throw new ForbiddenException('Tenant context is required for permission verification');
    }

    // 1. Tenant Admins automatically inherit ALL permissions within their organization
    const tenant = await this.tenantModel.findOne({
      tenant_id: tenantId,
      is_active: true,
    });

    if (tenant && tenant.admin_user_id === user.user_id) {
      request.department_codes = ['ADMINISTRATOR'];
      return true;
    }

    // 2. Fetch the user's active tenant membership and allocated departments
    let membership = request.tenant_membership;
    if (!membership) {
      membership = await this.membershipModel.findOne({
        user_id: user.user_id,
        tenant_id: tenantId,
        is_active: true,
      });
    }

    if (!membership) {
      throw new ForbiddenException(
        `Access denied: You are not assigned to any active departments in this tenant organization`,
      );
    }

    // 3. Retrieve all active departments the user is assigned to
    let departments = await this.departmentModel.find({
      department_id: { $in: membership.department_ids || [] },
      is_active: true,
    });

    // Self-healing: If user has no active departments found (due to legacy department IDs), auto-resolve to active fixed departments
    if (departments.length === 0) {
      const fixedDepts = await this.departmentModel.find({
        is_active: true,
      });

      if (fixedDepts.length > 0) {
        const oldDepts = await this.departmentModel.find({
          $or: [{ tenant_id: tenantId }, { tenant_id: null }],
          department_id: { $in: membership.department_ids || [] },
        });

        const recoveredDeptIds: string[] = [];
        for (const oldD of oldDepts) {
          const oldName = (oldD.department_name || '').trim().toLowerCase();
          if (!oldName) continue;
          const mapped = fixedDepts.find((f) => {
            const fName = f.department_name.toLowerCase();
            return fName === oldName ||
              (fName === 'qc' && QUALITY_DEPARTMENT_NAME.test(oldName)) ||
              (fName === 'packer' && PACKING_DEPARTMENT_NAME.test(oldName)) ||
              (fName !== 'administrator' &&
              (fName.includes(oldName) || oldName.includes(fName)));
          });
          if (mapped) recoveredDeptIds.push(mapped.department_id);
        }

        const newDeptIds = [...new Set(recoveredDeptIds)];
        if (newDeptIds.length > 0) {
          membership.department_ids = newDeptIds;
          await this.membershipModel.updateOne(
            { _id: membership._id },
            { $set: { department_ids: newDeptIds } },
          );
        }

        departments = fixedDepts.filter((d) =>
          newDeptIds.includes(d.department_id),
        );
      }
    }

    if (departments.length === 0) {
      throw new ForbiddenException(
        `Access denied: You are not assigned to any active departments in this tenant organization`,
      );
    }

    request.department_codes = FIXED_DEPARTMENTS.filter((fixed) =>
      departments.some((department) =>
        department.department_id === fixed.department_id ||
        department.department_name.trim().toLowerCase() === fixed.name.toLowerCase() ||
        (fixed.code === 'QC' && QUALITY_DEPARTMENT_NAME.test(department.department_name)) ||
        (fixed.code === 'PACKER' && PACKING_DEPARTMENT_NAME.test(department.department_name)),
      ),
    ).map((department) => department.code);
    request.confirmed_orders_only = request.department_codes.some(
      (code: string) => code === 'SUPERVISOR' || code === 'PRODUCTION_MANAGER' || code === 'ACCOUNTS',
    ) && !request.department_codes.includes('ADMINISTRATOR') &&
      !request.department_codes.includes('SALES');

    // 4. Users with the Administrator department inherit full access across all modules
    if (
      departments.some(
        (d) => d.department_name.toLowerCase() === 'administrator',
      )
    ) {
      return true;
    }

    // 5. Aggregate all permission IDs granted across the user's departments (Department-Centric RBAC)
    const aggregatedPermissions = new Set<string>();
    for (const dept of departments) {
      if (Array.isArray(dept.permission_ids)) {
        for (const perm of dept.permission_ids) {
          aggregatedPermissions.add(perm);
        }
      }
    }

    // Legacy Quality departments can predate the fixed QC permission set.
    if (request.department_codes.includes('QC')) {
      aggregatedPermissions.add('permission.qc.check');
    }

    // Auto-grant read permission if user has any action permission in that module
    for (const perm of Array.from(aggregatedPermissions)) {
      const parts = perm.split('.');
      if (parts.length >= 3) {
        aggregatedPermissions.add(`permission.${parts[1]}.read`);
      }
    }

    // 5. Verify that every required permission (ALL) is present if specified
    if (requiredPermissions && requiredPermissions.length > 0) {
      const missingPermissions = requiredPermissions.filter(
        (perm) => !aggregatedPermissions.has(perm),
      );

      if (missingPermissions.length > 0) {
        throw new ForbiddenException(
          `Access denied: Your assigned departments do not grant the required permission(s): [${missingPermissions.join(
            ', ',
          )}]. Contact your Tenant Admin to update your department allocations.`,
        );
      }
    }

    // 6. Verify that at least one required permission (ANY) is present if specified
    if (requireAnyPermissions && requireAnyPermissions.length > 0) {
      const hasAtLeastOne = requireAnyPermissions.some((perm) =>
        aggregatedPermissions.has(perm),
      );

      if (!hasAtLeastOne) {
        throw new ForbiddenException(
          `Access denied: This module requires at least one of the following permissions: [${requireAnyPermissions.join(
            ', ',
          )}]. Contact your Tenant Admin to update your department allocations.`,
        );
      }
    }

    return true;
  }
}

