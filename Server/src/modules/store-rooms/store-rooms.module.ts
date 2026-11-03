import { Module } from '@nestjs/common';
import { StoreRoomsController } from './store-rooms.controller';
import { StoreRoomsService } from './store-rooms.service';
import { DatabaseModule } from '../../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [StoreRoomsController],
  providers: [StoreRoomsService],
  exports: [StoreRoomsService],
})
export class StoreRoomsModule {}

