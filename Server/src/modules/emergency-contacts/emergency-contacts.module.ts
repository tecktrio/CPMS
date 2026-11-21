import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  EmergencyContact,
  EmergencyContactSchema,
} from '../../database/schemas/emergency-contact.schema';
import { Tenant, TenantSchema } from '../../database/schemas/tenant.schema';
import {
  Department,
  DepartmentSchema,
} from '../../database/schemas/department.schema';
import {
  TenantMembership,
  TenantMembershipSchema,
} from '../../database/schemas/tenant-membership.schema';
import { EmergencyContactsService } from './emergency-contacts.service';
import { EmergencyContactsController } from './emergency-contacts.controller';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: EmergencyContact.name, schema: EmergencyContactSchema },
      { name: Tenant.name, schema: TenantSchema },
      { name: Department.name, schema: DepartmentSchema },
      { name: TenantMembership.name, schema: TenantMembershipSchema },
    ]),
  ],
  controllers: [EmergencyContactsController],
  providers: [EmergencyContactsService],
  exports: [EmergencyContactsService],
})
export class EmergencyContactsModule {}
