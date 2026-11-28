import * as assert from 'node:assert/strict';
import { test } from 'node:test';
import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { OrderWorkController } from '../src/modules/purchase-orders/order-work.controller';
import { ItemAssignmentStage, OrderWorkService } from '../src/modules/purchase-orders/order-work.service';
import { DepartmentsService } from '../src/modules/departments/departments.service';
import { AssignmentStaffService } from '../src/modules/production/assignment-staff.service';
import { ProductionService } from '../src/modules/production/production.service';

function query<T>(data: T) {
  return {
    sort() { return this; },
    select() { return this; },
    lean: async () => data,
  };
}

const order = {
  po_id: 'po',
  po_number: 'PO-124',
  tenant_id: 'tenant',
  status: 'CONFIRMED',
  customer_name: 'Customer',
  customer_address: 'Private address',
  total_cartons: 10,
  items: [
    { item_id: 'first', item_name: 'First', qa_user_id: 'my-user', cartons: 5, packed_cartons: 3 },
    { item_id: 'second', item_name: 'Second', qa_user_id: 'other-user', cartons: 5, packed_cartons: 1 },
  ],
};

const assignment = {
  assignment_id: 'assignment',
  po_id: 'po',
  item_id: 'first',
  supervisor_user_id: 'my-user',
  assigned_cartons: 5,
  completed_cartons: 2,
};

function work(orders: object, assignments: object = {}) {
  return new OrderWorkService(orders as never, assignments as never, null, null, null, null);
}

test('supervisor records are filtered to the signed-in user and their assigned items', async () => {
  let orderFilter: any;
  let assignmentFilter: any;
  const service = work({
    find(filter: any) {
      orderFilter = filter;
      return query([order]);
    },
  }, {
    find(filter: any) {
      assignmentFilter = filter;
      return query([assignment]);
    },
  });
  const [result] = await service.list('tenant', 'my-user', 'SUPERVISOR');
  assert.equal(assignmentFilter.tenant_id, 'tenant');
  assert.equal(assignmentFilter.supervisor_user_id, 'my-user');
  assert.deepEqual(orderFilter.po_id, { $in: ['po'] });
  assert.equal(orderFilter.status.$in.includes('DRAFT'), false);
  assert.ok('items' in result);
  assert.deepEqual(result.items.map((item) => item.item_id), ['first']);
  assert.equal('customer_address' in result, false);
});

test('QA records contain only assigned lines and checks require matching tenant and owner', async () => {
  const service = work({
    find: () => query([order]),
    findOne(filter: any) {
      assert.equal(filter.tenant_id, 'tenant');
      assert.equal(filter.po_id, 'po');
      assert.deepEqual(filter.items.$elemMatch, {
        item_id: 'second', qa_user_id: 'my-user', qa_checked_at: null,
      });
      return query(null);
    },
    updateOne() { assert.fail('An unassigned item must not be changed'); },
  });
  const [result] = await service.list('tenant', 'my-user', 'QC');
  assert.ok('items' in result);
  assert.deepEqual(result.items.map((item) => item.item_id), ['first']);
  await assert.rejects(service.checkQuality('tenant', 'my-user', 'po', 'second'), NotFoundException);
});

test('export receives counts and basic order details without line or customer address data', async () => {
  const service = work({ find: () => query([order]) });
  const [result] = await service.list('tenant', 'my-user', 'EXPORT');
  assert.equal(result.po_number, 'PO-124');
  assert.equal('packed_cartons' in result && result.packed_cartons, 4);
  assert.equal('items' in result, false);
  assert.equal('customer_address' in result, false);
});

test('workflow selection cannot grant access to another department', () => {
  const controller = new OrderWorkController(null);
  assert.throws(
    () => controller.list('tenant', 'my-user', { department_codes: ['EXPORT'] }, 'ACCOUNTS'),
    ForbiddenException,
  );
});

test('production progress cannot change another supervisor’s assignment', async () => {
  const service = new ProductionService({
    findOne(filter: any) {
      assert.equal(filter.tenant_id, 'tenant');
      assert.equal(filter.assignment_id, 'assignment');
      assert.equal(filter.supervisor_user_id, 'other-user');
      return null;
    },
  } as never, null, null);
  await assert.rejects(
    service.updateProgress('tenant', 'assignment', 'other-user', { completed_cartons: 3 }),
    NotFoundException,
  );
});

test('an assigned QA check records an optional note and identifies the actor', async () => {
  let update: any;
  const service = work({
    findOne: () => query(order),
    updateOne(filter: any, operations: any) {
      assert.equal(filter.items.$elemMatch.qa_user_id, 'my-user');
      update = operations[0].$set;
      return { matchedCount: 1 };
    },
  });
  assert.deepEqual(await service.checkQuality('tenant', 'my-user', 'po', 'first', ' Seal intact '), {
    success: true,
  });
  const [event] = update.activity.$concatArrays[1].$literal;
  assert.equal(event.user_id, 'my-user');
  assert.equal(event.action, 'Marked item checked');
  assert.equal(event.detail, 'First · Seal intact');
});

test('the QA picker and assignment validation resolve Quality Assurance members in the active tenant', async () => {
  const staff = new AssignmentStaffService({
    find(filter: any) {
      assert.ok(filter.department_name.test('Quality Assurance'));
      assert.ok(filter.department_name.test('QC'));
      assert.equal(filter.department_name.test('Sales'), false);
      assert.deepEqual(filter.$or, [{ tenant_id: 'tenant' }, { tenant_id: null }]);
      return [{ department_id: 'quality-id' }];
    },
  } as never, {
    find(filter: any) {
      assert.equal(filter.tenant_id, 'tenant');
      assert.equal(filter.is_active, true);
      assert.deepEqual(filter.department_ids, { $in: ['quality-id'] });
      return filter.user_id === 'outside-user' ? [] : [{ user_id: 'qa-user' }];
    },
  } as never, {
    find(filter: any) {
      assert.deepEqual(filter.account_status.$nin, ['INACTIVE', 'SUSPENDED']);
      return { select: async () => filter.user_id.$in.length
        ? [{
          user_id: 'qa-user', full_name: 'QA Staff', email_address: 'qa@example.com',
          phone_number: '+91 90000 00001', avatar_url: '/avatars/qa.png',
        }]
        : [] };
    },
  } as never);

  const expected = {
    user_id: 'qa-user', name: 'QA Staff', email_address: 'qa@example.com',
    phone_number: '+91 90000 00001', avatar_url: '/avatars/qa.png',
  };
  assert.deepEqual(await staff.list('tenant', 'QC'), [expected]);
  assert.deepEqual(await staff.requireMember('tenant', 'QC', 'qa-user'), expected);
  await assert.rejects(staff.requireMember('tenant', 'QC', 'outside-user'));
});

test('startup remaps legacy QA memberships without reactivating disabled memberships', async () => {
  const membership = {
    user_id: 'qa-user',
    department_ids: ['legacy-qa'],
    is_active: false,
    async save() {},
  };
  const service = new DepartmentsService({
    find(filter: any) {
      assert.deepEqual(filter.department_id, { $in: ['legacy-qa'] });
      assert.ok(filter.department_name.test('QA'));
      assert.deepEqual(filter.$or, [{ tenant_id: 'tenant' }, { tenant_id: null }]);
      return { select: async () => [{ department_id: 'legacy-qa' }] };
    },
  } as never, {
    find: async () => [{ tenant_id: 'tenant', company_name: 'Tenant' }],
  } as never, {
    find: async () => [membership],
  } as never, null);
  service.seedFixedDepartments = async () => [
    { department_id: 'canonical-qa', department_name: 'QC' },
  ] as never;

  await service.migrateAllTenantsToFixedDepartments();
  assert.deepEqual(membership.department_ids, ['canonical-qa']);
  assert.equal(membership.is_active, false);
});

test('progress history records each quantity change once on the assignment', async () => {
  let saves = 0;
  const history: { at: Date; user_id: string; previous_cartons: number; completed_cartons: number }[] = [];
  const record = {
    ...assignment, completed_cartons: 0, supervisor_name: 'Supervisor', progress_history: history,
    async save() { saves++; },
  };
  const service = new ProductionService(
    { findOne: async () => record } as never,
    { exists: async () => true, findOne: async () => null } as never,
    null,
  );
  await service.updateProgress('tenant', 'assignment', 'my-user', { completed_cartons: 2 });
  await service.updateProgress('tenant', 'assignment', 'my-user', { completed_cartons: 2 });
  await service.updateProgress('tenant', 'assignment', 'my-user', { completed_cartons: 5 });
  assert.equal(saves, 2);
  assert.deepEqual(
    record.progress_history.map(({ previous_cartons, completed_cartons }) => [previous_cartons, completed_cartons]),
    [[0, 2], [2, 5]],
  );
  assert.ok(record.progress_history.every(({ at, user_id }) => at instanceof Date && user_id === 'my-user'));
});

test('QA history is written in the same update as the completion timestamp', async () => {
  const service = work({
    findOne: () => query(order),
    async updateOne(_filter: unknown, pipeline: any[]) {
      const update = pipeline[0].$set.items.$map.in.$cond[1].$mergeObjects[1];
      const [entry] = update.qa_completion_history.$concatArrays[1].$literal;
      assert.equal(entry.at, update.qa_checked_at);
      assert.equal(entry.user_id, 'my-user');
      assert.equal(entry.note, 'Passed');
      return { matchedCount: 1 };
    },
  });
  await service.checkQuality('tenant', 'my-user', 'po', 'first', ' Passed ');
});

test('packing and export assignments require matching department staff and current ownership', async () => {
  const staffChecks: unknown[][] = [];
  const writes: { filter: any; update: any }[] = [];
  const service = new OrderWorkService({
    async updateOne(filter, update) {
      writes.push({ filter, update });
      return { matchedCount: filter.items.$elemMatch['packing_assignment.user_id'] === 'stale' ? 0 : 1 };
    },
  } as never, null, null, null, {
    async requireMember(...args) {
      staffChecks.push(args);
      if (args[2] === 'wrong-user') throw new ForbiddenException();
      return { user_id: args[2], name: 'Assigned worker' };
    },
  } as never, null);

  await service.setItemAssignment('tenant', 'manager', 'po', 'first', ItemAssignmentStage.Packing, 'packer', null);
  await service.setItemAssignment('tenant', 'manager', 'po', 'first', ItemAssignmentStage.Export, 'exporter', null);
  await service.setItemAssignment('tenant', 'manager', 'po', 'first', ItemAssignmentStage.Export, null, 'exporter');
  await assert.rejects(
    service.setItemAssignment('tenant', 'manager', 'po', 'first', ItemAssignmentStage.Packing, null, 'stale'),
    ConflictException,
  );
  await assert.rejects(
    service.setItemAssignment('tenant', 'manager', 'po', 'first', ItemAssignmentStage.Export, 'wrong-user', null),
    ForbiddenException,
  );
  assert.deepEqual(staffChecks, [
    ['tenant', 'Packer', 'packer'],
    ['tenant', 'Export', 'exporter'],
    ['tenant', 'Export', 'wrong-user'],
  ]);
  assert.equal(writes.length, 4);
  assert.equal(writes[0].filter.tenant_id, 'tenant');
  assert.deepEqual(writes[0].filter.items.$elemMatch, { item_id: 'first', 'packing_assignment.user_id': null });
  assert.equal(writes[0].update.$set['items.$.packing_assignment'].user_id, 'packer');
  assert.equal(writes[1].update.$set['items.$.export_assignment'].user_id, 'exporter');
  assert.equal(writes[2].filter.items.$elemMatch['export_assignment.user_id'], 'exporter');
  assert.equal(writes[2].update.$set['items.$.export_assignment'], null);
});

test('workers can identify their own packing and export assignments', async () => {
  const assignedOrder = {
    ...order,
    items: [
      { ...order.items[0], packing_assignment: { user_id: 'packer' }, export_assignment: { user_id: 'exporter' } },
      { ...order.items[1], export_assignment: { user_id: 'different-exporter' } },
    ],
  };
  const service = work({ find: () => query([assignedOrder]) });
  const [packing] = await service.list('tenant', 'packer', 'PACKER');
  const [shipping] = await service.list('tenant', 'exporter', 'EXPORT');
  assert.ok('items' in packing);
  assert.ok('assigned_items' in shipping);
  assert.deepEqual(packing.items.map((item) => 'assigned_to_me' in item && item.assigned_to_me), [true, false]);
  assert.deepEqual(shipping.assigned_items.map((item) => item.item_id), ['first']);
});
