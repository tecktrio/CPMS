const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

// Read MONGODB_URI from .env if present
const envPath = path.resolve(__dirname, '../.env');
let uri = 'mongodb://127.0.0.1:27017/cpms_database';

if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (trimmed.startsWith('MONGODB_URI=')) {
      uri = trimmed.replace('MONGODB_URI=', '').trim();
      break;
    }
  }
}

const FIXED_DEPARTMENTS = [
  {
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
    code: 'SALES',
    name: 'Sales',
    description: 'Manages purchase orders, customer registries, and delivery requests.',
    permission_ids: [
      'permission.po.create',
      'permission.po.read',
      'permission.po.update',
      'permission.item.read',
      'permission.qc.read',
    ],
  },
  {
    code: 'STORE_ROOM',
    name: 'Store Room',
    description: 'Manages store rooms, cold chain locations, storage divisions, and stock batches.',
    permission_ids: [
      'permission.storeroom.create',
      'permission.storeroom.read',
      'permission.storeroom.update',
      'permission.storeroom.delete',
      'permission.item.read',
      'permission.batch.create',
      'permission.batch.read',
      'permission.batch.update',
      'permission.batch.deduct',
      'permission.po.read',
    ],
  },
  {
    code: 'PRODUCTION_MANAGER',
    name: 'Production Manager',
    description: 'Oversees product master, materials, and assigns supervisors to PO line items.',
    permission_ids: [
      'permission.item.create',
      'permission.item.read',
      'permission.item.update',
      'permission.item.delete',
      'permission.item_category.manage',
      'permission.packaging_material.manage',
      'permission.storeroom.read',
      'permission.po.read',
      'permission.batch.create',
      'permission.batch.read',
      'permission.batch.update',
      'permission.batch.deduct',
      'permission.production.read',
      'permission.production.create',
      'permission.production.update',
      'permission.production.delete',
      'permission.qc.read',
    ],
  },
  {
    code: 'SUPERVISOR',
    name: 'Supervisor',
    description: 'Executes allocated production lines and logs real-time completed carton counts.',
    permission_ids: [
      'permission.item.read',
      'permission.storeroom.read',
      'permission.po.read',
      'permission.batch.read',
      'permission.production.read',
      'permission.production.update',
    ],
  },
  {
    code: 'QC',
    name: 'QC',
    description: 'Inspects produced items, performs test audits, and files inspection reports.',
    permission_ids: [
      'permission.item.read',
      'permission.item.update',
      'permission.batch.read',
      'permission.storeroom.read',
      'permission.po.read',
      'permission.qc.read',
      'permission.qc.create',
      'permission.qc.update',
    ],
  },
  {
    code: 'PACKER',
    name: 'Packer',
    description: 'Packages goods into cartons, applies packaging specifications, and updates packed counts.',
    permission_ids: [
      'permission.po.read',
      'permission.item.read',
      'permission.packing.update',
    ],
  },
  {
    code: 'EXPORT',
    name: 'Export',
    description: 'Handles dispatch logistics, container allocation, and records shipped cartons.',
    permission_ids: [
      'permission.po.read',
      'permission.po.update',
      'permission.item.read',
      'permission.qc.read',
      'permission.export.update',
    ],
  },
  {
    code: 'ACCOUNTS',
    name: 'Accounts',
    description: 'Audits purchase order volumes, line shipments, and inventory valuation.',
    permission_ids: [
      'permission.po.read',
      'permission.item.read',
    ],
  },
];

async function migrate() {
  console.log('Connecting to database...');
  await mongoose.connect(uri);
  console.log('Connected to MongoDB.');

  const db = mongoose.connection.db;
  const tenants = await db.collection('tenants').find({}).toArray();
  console.log(`Found ${tenants.length} tenant(s) to migrate.`);

  for (const tenant of tenants) {
    console.log(`\nProcessing tenant: "${tenant.company_name}" (${tenant.tenant_id})`);
    const seededDeptIds = [];

    for (const fixed of FIXED_DEPARTMENTS) {
      const existing = await db.collection('departments').findOne({
        tenant_id: tenant.tenant_id,
        department_name: { $regex: new RegExp(`^${fixed.name}$`, 'i') },
      });

      if (existing) {
        await db.collection('departments').updateOne(
          { _id: existing._id },
          {
            $set: {
              department_name: fixed.name,
              permission_ids: fixed.permission_ids,
              description: fixed.description,
              is_active: true,
              updated_at: new Date(),
            },
          },
        );
        seededDeptIds.push(existing.department_id);
        console.log(`  ✓ Updated existing department: ${fixed.name} (${existing.department_id})`);
      } else {
        const newId = uuidv4();
        await db.collection('departments').insertOne({
          department_id: newId,
          tenant_id: tenant.tenant_id,
          department_name: fixed.name,
          description: fixed.description,
          permission_ids: fixed.permission_ids,
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        });
        seededDeptIds.push(newId);
        console.log(`  + Created missing department: ${fixed.name} (${newId})`);
      }
    }

    // Deactivate non-fixed legacy departments
    const deactivatedResult = await db.collection('departments').updateMany(
      {
        tenant_id: tenant.tenant_id,
        department_id: { $nin: seededDeptIds },
      },
      {
        $set: { is_active: false, updated_at: new Date() },
      },
    );
    if (deactivatedResult.modifiedCount > 0) {
      console.log(`  - Deactivated ${deactivatedResult.modifiedCount} legacy custom department(s).`);
    }

    // Ensure tenant admin has all 9 fixed departments
    if (tenant.admin_user_id) {
      await db.collection('tenant_memberships').updateOne(
        {
          tenant_id: tenant.tenant_id,
          user_id: tenant.admin_user_id,
        },
        {
          $addToSet: { department_ids: { $each: seededDeptIds } },
        },
      );
      console.log(`  ✓ Updated admin (${tenant.admin_user_id}) membership with all 9 fixed department IDs.`);
    }
  }

  console.log('\nAll existing tenants successfully migrated to fixed preset departments!');
  await mongoose.disconnect();
  process.exit(0);
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});

