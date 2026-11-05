import {
  Injectable,
  OnModuleInit,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  Permission,
  PermissionDocument,
} from '../../database/schemas/permission.schema';
import { SYSTEM_PERMISSIONS } from './permissions.constants';

@Injectable()
export class PermissionsService implements OnModuleInit {
  private readonly logger = new Logger(PermissionsService.name);

  constructor(
    @InjectModel(Permission.name)
    private readonly permissionModel: Model<PermissionDocument>,
  ) {}

  async onModuleInit() {
    await this.seedPermissions();
  }

  /**
   * Automatically seed system permissions on startup if not already seeded
   */
  async seedPermissions(): Promise<void> {
    try {
      for (const perm of SYSTEM_PERMISSIONS) {
        await this.permissionModel.updateOne(
          { permission_id: perm.permission_id },
          { $set: perm },
          { upsert: true },
        );
      }
      this.logger.log(
        `Seeded/verified ${SYSTEM_PERMISSIONS.length} system RBAC permissions.`,
      );
    } catch (err: any) {
      this.logger.warn(`Could not seed system permissions: ${err?.message}`);
    }
  }

  async findAll(): Promise<Permission[]> {
    const list = await this.permissionModel.find().sort({ module: 1, action: 1 });
    if (list.length > 0) {
      return list;
    }
    return SYSTEM_PERMISSIONS as any;
  }

  async getGroupedByModule(): Promise<Record<string, Permission[]>> {
    const all = await this.findAll();
    const grouped: Record<string, Permission[]> = {};

    for (const perm of all) {
      if (!grouped[perm.module]) {
        grouped[perm.module] = [];
      }
      grouped[perm.module].push(perm);
    }

    return grouped;
  }

  /**
   * Validates that all provided permission IDs exist in the system catalogue
   */
  async validatePermissionIds(permissionIds: string[]): Promise<void> {
    if (!permissionIds || permissionIds.length === 0) {
      return;
    }

    const validIds = new Set(SYSTEM_PERMISSIONS.map((p) => p.permission_id));
    const invalidIds = permissionIds.filter((id) => !validIds.has(id));

    if (invalidIds.length > 0) {
      throw new BadRequestException(
        `Invalid permission ID(s) provided: ${invalidIds.join(
          ', ',
        )}. Please select valid permissions from the system catalogue.`,
      );
    }
  }
}

