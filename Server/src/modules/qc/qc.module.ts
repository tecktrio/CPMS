import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { QcController } from './qc.controller';
import { QcService } from './qc.service';

@Module({
  imports: [DatabaseModule],
  controllers: [QcController],
  providers: [QcService],
  exports: [QcService],
})
export class QcModule {}

