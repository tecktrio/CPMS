class AppPermissions {
  // Items & Raw Materials
  static const String itemCreate = 'permission.item.create';
  static const String itemRead = 'permission.item.read';
  static const String itemUpdate = 'permission.item.update';
  static const String itemDelete = 'permission.item.delete';

  // Store Rooms / Cold Storage
  static const String storeroomCreate = 'permission.storeroom.create';
  static const String storeroomRead = 'permission.storeroom.read';
  static const String storeroomUpdate = 'permission.storeroom.update';
  static const String storeroomDelete = 'permission.storeroom.delete';

  // Stock Batches & FEFO Picking
  static const String batchCreate = 'permission.batch.create';
  static const String batchRead = 'permission.batch.read';
  static const String batchUpdate = 'permission.batch.update';
  static const String batchDeduct = 'permission.batch.deduct';

  // Departments & RBAC
  static const String departmentCreate = 'permission.department.create';
  static const String departmentRead = 'permission.department.read';
  static const String departmentUpdate = 'permission.department.update';
  static const String departmentDelete = 'permission.department.delete';

  // Users Directory & Management
  static const String userAdd = 'permission.user.add';
  static const String userRead = 'permission.user.read';
  static const String userUpdate = 'permission.user.update';
  static const String userDelete = 'permission.user.delete';

  // BOM & Purchase Orders (Phase 2)
  static const String bomCreate = 'permission.bom.create';
  static const String bomRead = 'permission.bom.read';
  static const String bomUpdate = 'permission.bom.update';
  static const String bomDelete = 'permission.bom.delete';

  static const String poCreate = 'permission.po.create';
  static const String poRead = 'permission.po.read';
  static const String poUpdate = 'permission.po.update';
  static const String poDelete = 'permission.po.delete';
}

