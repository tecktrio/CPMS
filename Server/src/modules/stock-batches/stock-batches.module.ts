import { Module } from '@nestjs/common';
import { StockBatchesController } from './stock-batches.controller';
import { StockBatchesService } from './stock-batches.service';
import { DatabaseModule } from '../../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [StockBatchesController],
  providers: [StockBatchesService],
  exports: [StockBatchesService],
})
export class StockBatchesModule {}

