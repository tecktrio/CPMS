export interface SystemPermissionDefinition {
  permission_id: string;
  module: string;
  action: 'CREATE' | 'READ' | 'UPDATE' | 'DELETE' | 'ALLOCATE' | 'EXECUTE';
  display_name: string;
  description: string;
}

export const SYSTEM_PERMISSIONS: SystemPermissionDefinition[] = [
  // 1. Items & Raw Materials
  {
    permission_id: 'permission.item.create',
    module: 'Items',
    action: 'CREATE',
    display_name: 'Create Items',
    description: 'Allows registering raw materials, finished goods, and packaging SKUs.',
  },
  {
    permission_id: 'permission.item.read',
    module: 'Items',
    action: 'READ',
    display_name: 'View Items',
    description: 'Allows viewing item directory, available stock balances, and reorder levels.',
  },
  {
    permission_id: 'permission.item.update',
    module: 'Items',
    action: 'UPDATE',
    display_name: 'Update Items',
    description: 'Allows modifying item names, unit of measures, categories, and reorder thresholds.',
  },
  {
    permission_id: 'permission.item.delete',
    module: 'Items',
    action: 'DELETE',
    display_name: 'Deactivate Items',
    description: 'Allows deactivating or archiving item SKUs.',
  },
  {
    permission_id: 'permission.item_category.manage',
    module: 'Items',
    action: 'UPDATE',
    display_name: 'Manage Item Categories',
    description: 'Allows creating, updating, and deleting item categories for the tenant.',
  },
  {
    permission_id: 'permission.packaging_material.manage',
    module: 'Items',
    action: 'UPDATE',
    display_name: 'Manage Packaging Materials',
    description: 'Allows creating, updating, and deleting packaging materials for the tenant.',
  },

  // 2. Cold Store Rooms
  {
    permission_id: 'permission.storeroom.create',
    module: 'StoreRooms',
    action: 'CREATE',
    display_name: 'Create Store Rooms',
    description: 'Allows creating new cold store rooms with target temperature and capacity limits.',
  },
  {
    permission_id: 'permission.storeroom.read',
    module: 'StoreRooms',
    action: 'READ',
    display_name: 'View Store Rooms',
    description: 'Allows viewing store rooms, current stock occupancy, and capacity utilization.',
  },
  {
    permission_id: 'permission.storeroom.update',
    module: 'StoreRooms',
    action: 'UPDATE',
    display_name: 'Update Store Rooms',
    description: 'Allows updating store room specifications, target temperature ranges, and maximum capacities.',
  },
  {
    permission_id: 'permission.storeroom.delete',
    module: 'StoreRooms',
    action: 'DELETE',
    display_name: 'Deactivate Store Rooms',
    description: 'Allows deactivating cold store rooms with zero active stock.',
  },

  // 3. Departments & RBAC
  {
    permission_id: 'permission.department.create',
    module: 'Departments',
    action: 'CREATE',
    display_name: 'Create Departments',
    description: 'Allows creating new functional departments and assigning permission sets.',
  },
  {
    permission_id: 'permission.department.read',
    module: 'Departments',
    action: 'READ',
    display_name: 'View Departments',
    description: 'Allows viewing tenant departments and their assigned permissions.',
  },
  {
    permission_id: 'permission.department.update',
    module: 'Departments',
    action: 'UPDATE',
    display_name: 'Update Departments',
    description: 'Allows editing department names, descriptions, and permission allocations.',
  },
  {
    permission_id: 'permission.department.delete',
    module: 'Departments',
    action: 'DELETE',
    display_name: 'Deactivate Departments',
    description: 'Allows archiving departments not actively assigned to members.',
  },

  // 5. Tenant Users Management
  {
    permission_id: 'permission.user.add',
    module: 'Users',
    action: 'CREATE',
    display_name: 'Add Tenant Users',
    description: 'Allows adding new users into tenant and assigning their departments.',
  },
  {
    permission_id: 'permission.user.read',
    module: 'Users',
    action: 'READ',
    display_name: 'View Tenant Directory',
    description: 'Allows viewing all staff members and their department memberships.',
  },
  {
    permission_id: 'permission.user.update',
    module: 'Users',
    action: 'UPDATE',
    display_name: 'Update Tenant Users',
    description: 'Allows updating department assignments for existing members of the tenant organization.',
  },
  {
    permission_id: 'permission.user.delete',
    module: 'Users',
    action: 'DELETE',
    display_name: 'Remove Tenant Users',
    description: 'Allows removing members from the tenant organization or specific departments.',
  },

  // 6. Purchase Orders (Phase 2)
  {
    permission_id: 'permission.po.create',
    module: 'PurchaseOrders',
    action: 'CREATE',
    display_name: 'Create Purchase Orders',
    description: 'Allows creating and dispatching supplier purchase orders.',
  },
  {
    permission_id: 'permission.po.read',
    module: 'PurchaseOrders',
    action: 'READ',
    display_name: 'View Purchase Orders',
    description: 'Allows viewing purchase order statuses, receipts, and gap analysis.',
  },
  {
    permission_id: 'permission.po.update',
    module: 'PurchaseOrders',
    action: 'UPDATE',
    display_name: 'Update Purchase Orders',
    description: 'Allows updating delivery schedules and PO line quantities.',
  },
  {
    permission_id: 'permission.po.delete',
    module: 'PurchaseOrders',
    action: 'DELETE',
    display_name: 'Cancel Purchase Orders',
    description: 'Allows cancelling unfilled purchase orders.',
  },

  // 7. Production Module
  {
    permission_id: 'permission.production.create',
    module: 'Production',
    action: 'CREATE',
    display_name: 'Assign Production Lines',
    description: 'Allows allocating PO item quantities to production supervisors.',
  },
  {
    permission_id: 'permission.production.read',
    module: 'Production',
    action: 'READ',
    display_name: 'View Production Tasks',
    description: 'Allows viewing allocated production workloads and live line completions.',
  },
  {
    permission_id: 'permission.production.update',
    module: 'Production',
    action: 'UPDATE',
    display_name: 'Update Production Completion',
    description: 'Allows supervisors to update completed carton progress on assigned items.',
  },
  {
    permission_id: 'permission.production.delete',
    module: 'Production',
    action: 'DELETE',
    display_name: 'Cancel Production Assignment',
    description: 'Allows removing or revoking production supervisor assignments.',
  },

  // 8. Quality Control (QC)
  {
    permission_id: 'permission.qc.create',
    module: 'QC',
    action: 'CREATE',
    display_name: 'Submit QC Report',
    description: 'Allows filing inspection reports, lab verification, and sample audits.',
  },
  {
    permission_id: 'permission.qc.read',
    module: 'QC',
    action: 'READ',
    display_name: 'View QC Reports',
    description: 'Allows reviewing quality audit records and item test evaluations.',
  },
  {
    permission_id: 'permission.qc.update',
    module: 'QC',
    action: 'UPDATE',
    display_name: 'Update QC Status',
    description: 'Allows modifying QC inspection decisions, approvals, and reject counts.',
  },

  // 9. Packaging
  {
    permission_id: 'permission.packing.update',
    module: 'Packing',
    action: 'UPDATE',
    display_name: 'Update Packed Cartons',
    description: 'Allows packers to log packed cartons against purchase order items.',
  },

  // 10. Export & Dispatch
  {
    permission_id: 'permission.export.update',
    module: 'Export',
    action: 'UPDATE',
    display_name: 'Update Shipped Cartons',
    description: 'Allows export coordinators to log dispatched container cartons and shipping status.',
  },
];


