import * as assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { normalizeDivisions, StoreRoomsService } from '../src/modules/store-rooms/store-rooms.service';

function fixture() {
  const room = {
    divisions: [
      { division_id: 'a', name: 'Division - A' },
      { division_id: 'b', name: 'Division - B' },
    ],
    items: [
      { item_id: 'item', division_id: 'a', division: 'Division - A', quantity: 4, min_count: 2 },
      { item_id: 'item', division_id: 'b', division: 'Division - B', quantity: 7, min_count: 3 },
    ],
    async save() {},
  };
  const service = new StoreRoomsService({
    async findOne(query: object) {
      assert.deepEqual(query, { tenant_id: 'tenant', store_room_id: 'room' });
      return room;
    },
  } as never, null);
  return { room, service };
}

test('a division with items cannot be deleted', async () => {
  const { room, service } = fixture();
  await assert.rejects(
    service.update('tenant', 'room', { divisions: [room.divisions[1]] }),
    BadRequestException,
  );
  assert.equal(room.divisions.length, 2);
});

test('a move merges stock without duplicating it and frees the source division', async () => {
  const { room, service } = fixture();
  await service.moveItem('tenant', 'room', 'item', 'a', 'Division - A', 'b');
  await service.moveItem('tenant', 'room', 'item', 'a', 'Division - A', 'b');
  assert.deepEqual(room.items, [
    { item_id: 'item', division_id: 'b', division: 'Division - B', quantity: 11, min_count: 3 },
  ]);
  await service.update('tenant', 'room', { divisions: [room.divisions[1]] });
  assert.equal(room.divisions.length, 1);
});

test('division names are stored as entered and renaming preserves item assignments', async () => {
  assert.equal(normalizeDivisions(['uk'])[0].name, 'uk');
  assert.equal(normalizeDivisions(['UK Cold Room'])[0].name, 'UK Cold Room');
  const { room, service } = fixture();
  await service.update('tenant', 'room', {
    divisions: [{ division_id: 'a', name: 'uk' }, room.divisions[1]],
  });
  assert.equal(room.divisions[0].name, 'uk');
  assert.equal(room.items[0].division, 'uk');
  assert.equal(room.items[0].division_id, 'a');
});
