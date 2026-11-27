import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import { QcReport, QcReportDocument } from '../../database/schemas/qc-report.schema';
import {
  PurchaseOrder,
  PurchaseOrderDocument,
} from '../../database/schemas/purchase-order.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { CreateQcReportDto } from './dtos/create-qc-report.dto';

@Injectable()
export class QcService {
  constructor(
    @InjectModel(QcReport.name)
    private readonly qcReportModel: Model<QcReportDocument>,
    @InjectModel(PurchaseOrder.name)
    private readonly poModel: Model<PurchaseOrderDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
  ) {}

  async createReport(
    tenantId: string,
    inspectorUserId: string,
    dto: CreateQcReportDto,
  ) {
    const po = await this.poModel.findOne({
      tenant_id: tenantId,
      po_id: dto.po_id,
    });
    if (!po) {
      throw new NotFoundException(`Purchase Order "${dto.po_id}" not found`);
    }

    const item = po.items.find((it) => it.item_id === dto.item_id);
    if (!item) {
      throw new NotFoundException(
        `Item "${dto.item_id}" not found in Purchase Order "${po.po_number}"`,
      );
    }

    const inspector = await this.userModel.findOne({
      user_id: inspectorUserId,
    });

    const isPassed =
      dto.status === 'PASSED' || dto.status === 'CONDITIONAL_PASS';

    const newReport = new this.qcReportModel({
      qc_report_id: uuidv4(),
      tenant_id: tenantId,
      po_id: po.po_id,
      po_number: po.po_number,
      po_item_id: item.item_id,
      item_id: item.item_id,
      item_name: item.item_name,
      inspector_user_id: inspectorUserId,
      inspector_name:
        inspector?.full_name || inspector?.email_address || 'QC Inspector',
      status: dto.status,
      inspected_cartons: dto.inspected_cartons,
      rejected_cartons: dto.rejected_cartons || 0,
      remarks: dto.remarks?.trim() || '',
      attachment_urls: dto.attachment_urls || [],
      inspected_at: new Date(),
    });

    await newReport.save();

    // Sync PO line item
    item.qc_passed = isPassed;
    if (isPassed && item.item_status !== 'SHIPPED' && item.item_status !== 'PACKED') {
      item.item_status = 'QC_APPROVED';
    }

    // Recalculate total_qc_passed_items
    po.total_qc_passed_items = po.items.filter((it) => it.qc_passed).length;
    await po.save();

    return newReport;
  }

  async getReportsByPo(tenantId: string, poId: string, inspectorId?: string) {
    return this.qcReportModel
      .find({ tenant_id: tenantId, po_id: poId, ...(inspectorId && { inspector_user_id: inspectorId }) })
      .sort({ created_at: -1 });
  }

  async getReportById(tenantId: string, reportId: string, inspectorId?: string) {
    const report = await this.qcReportModel.findOne({
      tenant_id: tenantId,
      qc_report_id: reportId,
      ...(inspectorId && { inspector_user_id: inspectorId }),
    });
    if (!report) {
      throw new NotFoundException('QC Report not found');
    }
    return report;
  }
}

