import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './config/configuration';
import { DatabaseModule } from './database/database.module';
import { EmailModule } from './modules/email/email.module';
import { AuthModule } from './modules/auth/auth.module';
import { TenantsModule } from './modules/tenants/tenants.module';
import { UsersModule } from './modules/users/users.module';
import { StoreRoomsModule } from './modules/store-rooms/store-rooms.module';
import { ItemsModule } from './modules/items/items.module';
import { StockBatchesModule } from './modules/stock-batches/stock-batches.module';
import { DepartmentsModule } from './modules/departments/departments.module';
import { PermissionsModule } from './modules/permissions/permissions.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    DatabaseModule,
    EmailModule,
    AuthModule,
    TenantsModule,
    UsersModule,
    StoreRoomsModule,
    ItemsModule,
    StockBatchesModule,
    DepartmentsModule,
    PermissionsModule,
  ],
})
export class AppModule {}

