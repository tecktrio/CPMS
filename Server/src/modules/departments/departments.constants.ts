export interface FixedDepartmentDefinition {
  department_id: string;
  code: string;
  name: string;
  description: string;
  permission_ids: string[];
}

export const FIXED_DEPARTMENTS: FixedDepartmentDefinition[] = [
  {
    department_id: '5f3f8ae5-bdaa-47df-b6fb-2918d8893eb9',
    code: 'ADMINISTRATOR',
    name: 'Administrator',
    description: 'Full access to all operational modules, settings, and team delegations.',
    permission_ids: [
      'permission.item.create',
      'permission.item.read',
      'permission.item.update',
      'permission.item.delete',
      'permission.item_category.manage',
      'permission.packaging_material.manage',
      'permission.storeroom.create',
      'permission.storeroom.read',
      'permission.storeroom.update',
      'permission.storeroom.manage',
      'permission.storeroom.delete',
      'permission.department.read',
      'permission.user.read',
      'permission.user.add',
      'permission.user.update',
      'permission.user.delete',
      'permission.po.create',
      'permission.po.read',
      'permission.po.update',
      'permission.po.delete',
      'permission.batch.create',
      'permission.batch.read',
      'permission.batch.update',
      'permission.batch.deduct',
      'permission.production.read',
      'permission.production.create',
      'permission.production.update',
      'permission.production.delete',
      'permission.qc.read',
      'permission.qc.create',
      'permission.qc.update',
      'permission.packing.update',
      'permission.export.update',
    ],
  },
  {
    department_id: 'f1f3b89c-0320-453f-a100-011442c87571',
    code: 'SALES',
    name: 'Sales',
    description: 'Manages purchase orders, customer registries, and delivery requests.',
    permission_ids: [
      'permission.po.create',
      'permission.po.read',
      'permission.po.update',
      'permission.item.read',
    ],
  },
  {
    department_id: '5f07bdca-bcda-488f-99e7-c17a22f46c21',
    code: 'STORE_ROOM',
    name: 'Store Room',
    description: 'Manages store rooms, cold chain locations, storage divisions, and stock batches.',
    permission_ids: [
      'permission.storeroom.read',
      'permission.storeroom.update',
      'permission.item.read',
      'permission.batch.create',
      'permission.batch.read',
      'permission.batch.update',
      'permission.batch.deduct',
    ],
  },
  {
    department_id: '5e73e183-49bf-4b9b-b7cf-d99b7ab01b09',
    code: 'PRODUCTION_MANAGER',
    name: 'Production Manager',
    description: 'Oversees product master, materials, and assigns supervisors to PO line items.',
    permission_ids: [
      'permission.po.read',
      'permission.production.read',
      'permission.production.create',
      'permission.production.update',
      'permission.production.assign',
      'permission.production.delete',
    ],
  },
  {
    department_id: '82e9f288-4412-4086-b2d1-a56634af7839',
    code: 'SUPERVISOR',
    name: 'Supervisor',
    description: 'Executes allocated production lines, assigns tasks, and logs real-time completed carton counts.',
    permission_ids: [
      'permission.production.read',
      'permission.production.update',
    ],
  },
  {
    department_id: 'a7aef526-f95c-4848-8fe0-8d2e51ead5c6',
    code: 'QC',
    name: 'QC',
    description: 'Inspects produced items, performs test audits, and files inspection reports.',
    permission_ids: [
      'permission.qc.read',
      'permission.qc.check',
    ],
  },
  {
    department_id: '0ae4396a-1a13-4c5a-8c73-4c2c421bc0b8',
    code: 'PACKER',
    name: 'Packer',
    description: 'Packages goods into cartons, applies packaging specifications, and updates packed counts.',
    permission_ids: [
      'permission.packing.update',
    ],
  },
  {
    department_id: '652199a0-4718-446c-b9ab-28a91fff04e3',
    code: 'EXPORT',
    name: 'Export',
    description: 'Handles dispatch logistics, container allocation, and records shipped cartons.',
    permission_ids: [
      'permission.export.read',
      'permission.export.update',
    ],
  },
  {
    department_id: '943dc46e-b312-4641-bcfa-d531bc06db47',
    code: 'ACCOUNTS',
    name: 'Accounts',
    description: 'Audits purchase order volumes, line shipments, and inventory valuation.',
    permission_ids: [
      'permission.po.read',
    ],
  },
];

// Existing installations may still have memberships tied to a QA department
// created before the fixed department was named QC.
export const QUALITY_DEPARTMENT_NAME = /^\s*(?:QC|QA|quality(?:[\s_-]+(?:assurance|control))?(?:[\s_-]+(?:team|department))?)\s*$/i;

export const PACKING_DEPARTMENT_NAME = /^\s*(?:packer[s]?|packing(?:[\s_-]+(?:team|department))?)\s*$/i;
