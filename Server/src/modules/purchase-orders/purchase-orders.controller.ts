import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
} from '@nestjs/swagger';
import { PurchaseOrdersService } from './purchase-orders.service';
import {
  CreateCustomerDto,
  UpdateCustomerDto,
} from './dtos/customer.dto';
import {
  CreatePurchaseOrderDto,
  UpdatePurchaseOrderDto,
} from './dtos/purchase-order.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Purchase Orders & Customers')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant UUID',
  required: true,
})
@Controller()
@UseGuards(JwtAuthGuard, TenantGuard, PermissionsGuard)
export class PurchaseOrdersController {
  constructor(
    private readonly poService: PurchaseOrdersService,
  ) {}

  // ===================== CUSTOMERS =====================

  @Post('customers')
  @RequireAnyPermissions('permission.po.create', 'permission.po.update')
  @ApiOperation({ summary: 'Create new customer' })
  @ApiResponse({ status: 201, description: 'Customer created' })
  async createCustomer(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateCustomerDto,
  ) {
    return this.poService.createCustomer(tenantId, dto);
  }

  @Get('customers')
  @RequireAnyPermissions(
    'permission.po.read',
    'permission.po.create',
    'permission.po.update',
    'permission.po.delete',
  )
  @ApiOperation({ summary: 'List all active customers' })
  @ApiResponse({ status: 200, description: 'List of customers' })
  async findAllCustomers(@CurrentTenant() tenantId: string) {
    return this.poService.findAllCustomers(tenantId);
  }

  @Get('customers/:id')
  @RequireAnyPermissions(
    'permission.po.read',
    'permission.po.create',
    'permission.po.update',
    'permission.po.delete',
  )
  @ApiOperation({ summary: 'Get customer details' })
  @ApiResponse({ status: 200, description: 'Customer details' })
  async findOneCustomer(
    @CurrentTenant() tenantId: string,
    @Param('id') customerId: string,
  ) {
    return this.poService.findCustomerById(tenantId, customerId);
  }

  @Put('customers/:id')
  @RequirePermissions('permission.po.update')
  @ApiOperation({ summary: 'Update customer' })
  @ApiResponse({ status: 200, description: 'Customer updated' })
  async updateCustomer(
    @CurrentTenant() tenantId: string,
    @Param('id') customerId: string,
    @Body() dto: UpdateCustomerDto,
  ) {
    return this.poService.updateCustomer(tenantId, customerId, dto);
  }

  @Delete('customers/:id')
  @RequirePermissions('permission.po.delete')
  @ApiOperation({ summary: 'Delete customer' })
  @ApiResponse({ status: 200, description: 'Customer deleted' })
  async deleteCustomer(
    @CurrentTenant() tenantId: string,
    @Param('id') customerId: string,
  ) {
    return this.poService.deleteCustomer(tenantId, customerId);
  }

  // ===================== PURCHASE ORDERS =====================

  @Post('purchase-orders')
  @RequirePermissions('permission.po.create')
  @ApiOperation({ summary: 'Create new purchase order' })
  @ApiResponse({ status: 201, description: 'Purchase order created' })
  async createPO(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreatePurchaseOrderDto,
  ) {
    return this.poService.createPurchaseOrder(tenantId, dto);
  }

  @Get('purchase-orders')
  @RequireAnyPermissions(
    'permission.po.read',
    'permission.po.create',
    'permission.po.update',
    'permission.po.delete',
  )
  @ApiOperation({ summary: 'List all purchase orders' })
  @ApiResponse({ status: 200, description: 'List of purchase orders' })
  async findAllPOs(@CurrentTenant() tenantId: string) {
    return this.poService.findAllPurchaseOrders(tenantId);
  }

  @Get('purchase-orders/:id')
  @RequireAnyPermissions(
    'permission.po.read',
    'permission.po.create',
    'permission.po.update',
    'permission.po.delete',
  )
  @ApiOperation({ summary: 'Get purchase order details' })
  @ApiResponse({ status: 200, description: 'Purchase order details' })
  async findOnePO(
    @CurrentTenant() tenantId: string,
    @Param('id') poId: string,
  ) {
    return this.poService.findOnePurchaseOrder(tenantId, poId);
  }

  @Put('purchase-orders/:id')
  @RequirePermissions('permission.po.update')
  @ApiOperation({ summary: 'Update purchase order' })
  @ApiResponse({ status: 200, description: 'Purchase order updated' })
  async updatePO(
    @CurrentTenant() tenantId: string,
    @Param('id') poId: string,
    @Body() dto: UpdatePurchaseOrderDto,
  ) {
    return this.poService.updatePurchaseOrder(tenantId, poId, dto);
  }

  @Patch('purchase-orders/:poId/items/:itemId/packing')
  @RequirePermissions('permission.packing.update')
  @ApiOperation({ summary: 'Update packed cartons for a PO line item (Packer role)' })
  async updateItemPacking(
    @CurrentTenant() tenantId: string,
    @Param('poId') poId: string,
    @Param('itemId') itemId: string,
    @Body('packed_cartons') packedCartons: number,
  ) {
    return this.poService.updateItemPacking(
      tenantId,
      poId,
      itemId,
      Number(packedCartons) || 0,
    );
  }

  @Patch('purchase-orders/:poId/items/:itemId/shipping')
  @RequirePermissions('permission.export.update')
  @ApiOperation({ summary: 'Update shipped cartons and status for a PO line item (Export role)' })
  async updateItemShipping(
    @CurrentTenant() tenantId: string,
    @Param('poId') poId: string,
    @Param('itemId') itemId: string,
    @Body('shipped_cartons') shippedCartons: number,
    @Body('item_status') itemStatus?: string,
  ) {
    return this.poService.updateItemShipping(
      tenantId,
      poId,
      itemId,
      Number(shippedCartons) || 0,
      itemStatus,
    );
  }

  @Delete('purchase-orders/:id')
  @RequirePermissions('permission.po.delete')
  @ApiOperation({ summary: 'Delete purchase order' })
  @ApiResponse({ status: 200, description: 'Purchase order deleted' })
  async removePO(
    @CurrentTenant() tenantId: string,
    @Param('id') poId: string,
  ) {
    return this.poService.removePurchaseOrder(tenantId, poId);
  }
}

