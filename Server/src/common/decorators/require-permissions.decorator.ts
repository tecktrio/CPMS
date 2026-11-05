import { SetMetadata } from '@nestjs/common';

export const PERMISSIONS_KEY = 'required_permissions';
export const REQUIRE_ANY_KEY = 'require_any_permissions';

/**
 * Decorator to require ALL specified system RBAC permissions.
 * Example: @RequirePermissions('permission.department.read')
 */
export const RequirePermissions = (...permissions: string[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);

/**
 * Decorator to require AT LEAST ONE of the specified system RBAC permissions.
 * Example: @RequireAnyPermissions('permission.item.read', 'permission.item.create')
 */
export const RequireAnyPermissions = (...permissions: string[]) =>
  SetMetadata(REQUIRE_ANY_KEY, permissions);
