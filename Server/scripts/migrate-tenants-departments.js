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
    console.log(`\n=======================================================`);
    console.log(`Processing tenant: "${tenant.company_name}" (${tenant.tenant_id})`);
    const seededDeptIds = [];
    const fixedDepts = [];

    // 1. Seed / update the 9 fixed departments
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
        fixedDepts.push({ ...fixed, department_id: existing.department_id });
        console.log(`  ✓ Synced fixed department: ${fixed.name} (${existing.department_id})`);
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
        fixedDepts.push({ ...fixed, department_id: newId });
        console.log(`  + Created fixed department: ${fixed.name} (${newId})`);
      }
    }

    const adminDept = fixedDepts.find((d) => d.name.toLowerCase() === 'administrator') || fixedDepts[0];

    // 2. Query all existing departments (including inactive ones) to map to fixed
    const allTenantDepts = await db.collection('departments').find({ tenant_id: tenant.tenant_id }).toArray();
    const oldIdToFixedId = new Map();

    for (const oldD of allTenantDepts) {
      if (seededDeptIds.includes(oldD.department_id)) {
        oldIdToFixedId.set(oldD.department_id, oldD.department_id);
        continue;
      }

      const name = (oldD.department_name || '').toLowerCase().trim();
      let targetId = adminDept.department_id;

      if (name.includes('admin') || name.includes('manage') || name.includes('owner') || name.includes('exec') || name.includes('director')) {
        targetId = adminDept.department_id;
      } else if (name.includes('sale') || name.includes('order') || name.includes('cust') || name.includes('client')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'sales');
        if (match) targetId = match.department_id;
      } else if (name.includes('store') || name.includes('warehous') || name.includes('invent') || name.includes('stock')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'store room');
        if (match) targetId = match.department_id;
      } else if (name.includes('prod') && name.includes('super')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'supervisor');
        if (match) targetId = match.department_id;
      } else if (name.includes('prod') || name.includes('manufact') || name.includes('line')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'production manager');
        if (match) targetId = match.department_id;
      } else if (name.includes('super')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'supervisor');
        if (match) targetId = match.department_id;
      } else if (name.includes('qc') || name.includes('qual') || name.includes('inspect') || name.includes('test')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'qc');
        if (match) targetId = match.department_id;
      } else if (name.includes('pack') || name.includes('box')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'packer');
        if (match) targetId = match.department_id;
      } else if (name.includes('export') || name.includes('ship') || name.includes('dispatch') || name.includes('logist')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'export');
        if (match) targetId = match.department_id;
      } else if (name.includes('acc') || name.includes('finan') || name.includes('audit')) {
        const match = fixedDepts.find((d) => d.name.toLowerCase() === 'accounts');
        if (match) targetId = match.department_id;
      }

      oldIdToFixedId.set(oldD.department_id, targetId);
    }

    // 3. Deactivate legacy custom departments
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

    // 4. Migrate EVERY membership document for this tenant
    const memberships = await db.collection('tenant_memberships').find({ tenant_id: tenant.tenant_id }).toArray();
    console.log(`  Found ${memberships.length} member(s) to migrate:`);

    for (const mem of memberships) {
      const isOwner = tenant.admin_user_id === mem.user_id;

      // If owner or the only member, assign ALL 9 fixed departments
      if (isOwner || memberships.length === 1) {
        await db.collection('tenant_memberships').updateOne(
          { _id: mem._id },
          {
            $set: {
              department_ids: seededDeptIds,
              is_active: true,
              updated_at: new Date(),
            },
          },
        );
        console.log(`    ✓ Migrated owner/admin member (${mem.user_id}) -> Assigned all 9 fixed departments.`);
        continue;
      }

      // Map member's previous department IDs to fixed department IDs
      const newDeptIds = new Set();
      for (const oldId of mem.department_ids || []) {
        const mapped = oldIdToFixedId.get(oldId);
        if (mapped && seededDeptIds.includes(mapped)) {
          newDeptIds.add(mapped);
        }
      }

      if (newDeptIds.size === 0) {
        newDeptIds.add(adminDept.department_id);
      }

      const finalDeptIds = Array.from(newDeptIds);
      await db.collection('tenant_memberships').updateOne(
        { _id: mem._id },
        {
          $set: {
            department_ids: finalDeptIds,
            is_active: true,
            updated_at: new Date(),
          },
        },
      );
      console.log(`    ✓ Migrated staff member (${mem.user_id}) -> ${finalDeptIds.length} fixed department(s).`);
    }

    // 5. Ensure tenant.admin_user_id has a membership document
    if (tenant.admin_user_id) {
      await db.collection('tenant_memberships').updateOne(
        {
          tenant_id: tenant.tenant_id,
          user_id: tenant.admin_user_id,
        },
        {
          $set: {
            department_ids: seededDeptIds,
            is_active: true,
            updated_at: new Date(),
          },
        },
        { upsert: true },
      );
    }
  }

  console.log('\n=======================================================');
  console.log('All existing tenants and their user memberships successfully migrated!');
  await mongoose.disconnect();
  process.exit(0);
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
