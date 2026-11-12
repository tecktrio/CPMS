import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { User, UserSchema } from './schemas/user.schema';
import { Tenant, TenantSchema } from './schemas/tenant.schema';
import {
  TenantMembership,
  TenantMembershipSchema,
} from './schemas/tenant-membership.schema';
import { StoreRoom, StoreRoomSchema } from './schemas/store-room.schema';
import { Item, ItemSchema } from './schemas/item.schema';
import { StockBatch, StockBatchSchema } from './schemas/stock-batch.schema';
import { OtpRecord, OtpRecordSchema } from './schemas/otp-record.schema';
import { Department, DepartmentSchema } from './schemas/department.schema';
import { Permission, PermissionSchema } from './schemas/permission.schema';
import { Customer, CustomerSchema } from './schemas/customer.schema';
import {
  PurchaseOrder,
  PurchaseOrderSchema,
} from './schemas/purchase-order.schema';

@Module({
  imports: [
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        uri: configService.get<string>('database.uri'),
      }),
      inject: [ConfigService],
    }),
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: Tenant.name, schema: TenantSchema },
      { name: TenantMembership.name, schema: TenantMembershipSchema },
      { name: StoreRoom.name, schema: StoreRoomSchema },
      { name: Item.name, schema: ItemSchema },
      { name: StockBatch.name, schema: StockBatchSchema },
      { name: OtpRecord.name, schema: OtpRecordSchema },
      { name: Department.name, schema: DepartmentSchema },
      { name: Permission.name, schema: PermissionSchema },
      { name: Customer.name, schema: CustomerSchema },
      { name: PurchaseOrder.name, schema: PurchaseOrderSchema },
    ]),
  ],
  exports: [MongooseModule],
})
export class DatabaseModule {}

