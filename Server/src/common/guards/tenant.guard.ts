import {
  CanActivate,
  ExecutionContext,
  Injectable,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';

@Injectable()
export class TenantGuard implements CanActivate {
  constructor(
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user || !user.user_id) {
      throw new ForbiddenException('User must be authenticated');
    }

    const tenantId =
      request.headers['x-tenant-id'] || request.headers['x-tenant-id']?.toString();

    if (!tenantId) {
      throw new BadRequestException(
        'X-Tenant-ID header is required for this operational request',
      );
    }

    const membership = await this.membershipModel.findOne({
      user_id: user.user_id,
      tenant_id: tenantId,
      is_active: true,
    });

    if (!membership) {
      throw new ForbiddenException(
        'Access denied: You do not have an active membership in this tenant',
      );
    }

    // Attach tenant_id to request object for easy retrieval via @CurrentTenant()
    request.tenant_id = tenantId;
    request.tenant_membership = membership;

    return true;
  }
}

