import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
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

    if (!membership || !membership.department_ids || membership.department_ids.length === 0) {
      throw new ForbiddenException(
        `Access denied: You are not assigned to any active departments in this tenant organization`,
      );
    }

    // 3. Retrieve all active departments the user is assigned to
    const departments = await this.departmentModel.find({
      tenant_id: tenantId,
      department_id: { $in: membership.department_ids },
      is_active: true,
    });

    // 4. Aggregate all permission IDs granted across the user's departments (Department-Centric RBAC)
    const aggregatedPermissions = new Set<string>();
    for (const dept of departments) {
      if (Array.isArray(dept.permission_ids)) {
        for (const perm of dept.permission_ids) {
          aggregatedPermissions.add(perm);
        }
      }
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

