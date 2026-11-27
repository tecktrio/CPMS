import { Module } from '@nestjs/common';
import { ProductionModule } from '../production/production.module';
import { OrderWorkController } from './order-work.controller';
import { OrderWorkService } from './order-work.service';
import { DatabaseModule } from '../../database/database.module';
import { PurchaseOrdersController } from './purchase-orders.controller';
import { PurchaseOrdersService } from './purchase-orders.service';

@Module({
  imports: [DatabaseModule, ProductionModule],
  controllers: [PurchaseOrdersController, OrderWorkController],
  providers: [PurchaseOrdersService, OrderWorkService],
  exports: [PurchaseOrdersService],
})
export class PurchaseOrdersModule {}
