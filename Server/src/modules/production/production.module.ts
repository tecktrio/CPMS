import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AssignmentStaffService } from './assignment-staff.service';
import { ProductionController } from './production.controller';
import { ProductionService } from './production.service';

@Module({
  imports: [DatabaseModule],
  controllers: [ProductionController],
  providers: [ProductionService, AssignmentStaffService],
  exports: [ProductionService, AssignmentStaffService],
})
export class ProductionModule {}

