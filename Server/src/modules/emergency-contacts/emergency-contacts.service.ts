import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import {
  EmergencyContact,
  EmergencyContactDocument,
} from '../../database/schemas/emergency-contact.schema';
import { Tenant, TenantDocument } from '../../database/schemas/tenant.schema';
import {
  Department,
  DepartmentDocument,
} from '../../database/schemas/department.schema';
import { CreateEmergencyContactDto } from './dtos/create-emergency-contact.dto';
import { UpdateEmergencyContactDto } from './dtos/update-emergency-contact.dto';

@Injectable()
export class EmergencyContactsService {
  constructor(
    @InjectModel(EmergencyContact.name)
    private readonly contactModel: Model<EmergencyContactDocument>,
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    @InjectModel(Department.name)
    private readonly departmentModel: Model<DepartmentDocument>,
  ) {}

  async checkIsAdministrator(
    tenantId: string,
    userId: string,
    departmentIds: string[] = [],
  ): Promise<boolean> {
    const tenant = await this.tenantModel.findOne({
      tenant_id: tenantId,
      is_active: true,
    });
    if (!tenant) {
      throw new NotFoundException('Tenant organization not found');
    }

    // Tenant owner has automatic administrator privileges
    if (tenant.admin_user_id === userId) {
      return true;
    }

    // Check if user belongs to Administrator department
    if (departmentIds && departmentIds.length > 0) {
      const departments = await this.departmentModel.find({
        tenant_id: tenantId,
        department_id: { $in: departmentIds },
        is_active: true,
      });

      const isAdministrator = departments.some(
        (d) =>
          d.department_name.toLowerCase() === 'administrator' ||
          d.department_name.toLowerCase().includes('admin'),
      );

      if (isAdministrator) {
        return true;
      }
    }

    throw new ForbiddenException(
      'Only staff users in the Administrator department can update emergency contacts.',
    );
  }

  async findAll(tenantId: string): Promise<EmergencyContact[]> {
    const contacts = await this.contactModel
      .find({
        tenant_id: tenantId,
        is_active: true,
      })
      .sort({ priority_order: 1, created_at: 1 });

    if (contacts.length > 0) {
      return contacts;
    }

    // Seed preset initial emergency contacts for this tenant
    const defaultContacts = [
      {
        contact_id: uuidv4(),
        tenant_id: tenantId,
        title: 'Facility Security & Control',
        subtitle: 'Control Room • Ext. 101',
        phone_number: '+1 (800) 555-0199',
        icon_type: 'security',
        priority_order: 1,
        is_active: true,
      },
      {
        contact_id: uuidv4(),
        tenant_id: tenantId,
        title: 'Safety Coordinator (EHS)',
        subtitle: 'Tariq Vance • Lead Officer',
        phone_number: '+1 (800) 555-0142',
        icon_type: 'safety',
        priority_order: 2,
        is_active: true,
      },
      {
        contact_id: uuidv4(),
        tenant_id: tenantId,
        title: 'First Aid & Medical Bay',
        subtitle: 'Building B • Clinic Desk',
        phone_number: '+1 (800) 555-0188',
        icon_type: 'medical',
        priority_order: 3,
        is_active: true,
      },
    ];

    return (await this.contactModel.insertMany(
      defaultContacts,
    )) as unknown as EmergencyContact[];
  }

  async create(
    tenantId: string,
    userId: string,
    departmentIds: string[],
    dto: CreateEmergencyContactDto,
  ): Promise<EmergencyContact> {
    await this.checkIsAdministrator(tenantId, userId, departmentIds);

    const contact = new this.contactModel({
      contact_id: uuidv4(),
      tenant_id: tenantId,
      title: dto.title.trim(),
      subtitle: dto.subtitle?.trim() || '',
      phone_number: dto.phone_number.trim(),
      icon_type: dto.icon_type?.trim() || 'warning',
      priority_order: dto.priority_order ?? 0,
      is_active: true,
    });

    return contact.save();
  }

  async update(
    tenantId: string,
    userId: string,
    departmentIds: string[],
    contactId: string,
    dto: UpdateEmergencyContactDto,
  ): Promise<EmergencyContact> {
    await this.checkIsAdministrator(tenantId, userId, departmentIds);

    const contact = await this.contactModel.findOne({
      tenant_id: tenantId,
      contact_id: contactId,
      is_active: true,
    });

    if (!contact) {
      throw new NotFoundException('Emergency contact not found');
    }

    if (dto.title !== undefined) contact.title = dto.title.trim();
    if (dto.subtitle !== undefined) contact.subtitle = dto.subtitle.trim();
    if (dto.phone_number !== undefined)
      contact.phone_number = dto.phone_number.trim();
    if (dto.icon_type !== undefined) contact.icon_type = dto.icon_type.trim();
    if (dto.priority_order !== undefined)
      contact.priority_order = dto.priority_order;
    if (dto.is_active !== undefined) contact.is_active = dto.is_active;

    return contact.save();
  }

  async delete(
    tenantId: string,
    userId: string,
    departmentIds: string[],
    contactId: string,
  ): Promise<{ message: string; contact_id: string }> {
    await this.checkIsAdministrator(tenantId, userId, departmentIds);

    const contact = await this.contactModel.findOne({
      tenant_id: tenantId,
      contact_id: contactId,
      is_active: true,
    });

    if (!contact) {
      throw new NotFoundException('Emergency contact not found');
    }

    contact.is_active = false;
    await contact.save();

    return {
      message: 'Emergency contact removed successfully',
      contact_id: contactId,
    };
  }
}

