import { Module } from '@nestjs/common';
import { TenantsController } from './tenants.controller';
import { TenantsService } from './tenants.service';
import { DatabaseModule } from '../../database/database.module';
import { DepartmentsModule } from '../departments/departments.module';

@Module({
  imports: [DatabaseModule, DepartmentsModule],
  controllers: [TenantsController],
  providers: [TenantsService],
  exports: [TenantsService],
})
export class TenantsModule {}

