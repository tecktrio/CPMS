import { Module } from '@nestjs/common';
import { DepartmentsService } from './departments.service';
import { DepartmentsController } from './departments.controller';
import { PermissionsModule } from '../permissions/permissions.module';
import { DatabaseModule } from '../../database/database.module';

@Module({
  imports: [DatabaseModule, PermissionsModule],
  controllers: [DepartmentsController],
  providers: [DepartmentsService],
  exports: [DepartmentsService],
})
export class DepartmentsModule {}

