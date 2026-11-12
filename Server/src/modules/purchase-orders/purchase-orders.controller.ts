import {
  Controller,
  Get,
  Post,
  Put,
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
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Purchase Orders & Customers')
@ApiBearerAuth('jwt-auth')
@ApiHeader({
  name: 'X-Tenant-ID',
  description: 'Active tenant UUID',
  required: true,
})
@Controller()
@UseGuards(JwtAuthGuard, TenantGuard)
export class PurchaseOrdersController {
  constructor(
    private readonly poService: PurchaseOrdersService,
  ) {}

  // ===================== CUSTOMERS =====================

  @Post('customers')
  @ApiOperation({ summary: 'Create new customer' })
  @ApiResponse({ status: 201, description: 'Customer created' })
  async createCustomer(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreateCustomerDto,
  ) {
    return this.poService.createCustomer(tenantId, dto);
  }

  @Get('customers')
  @ApiOperation({ summary: 'List all active customers' })
  @ApiResponse({ status: 200, description: 'List of customers' })
  async findAllCustomers(@CurrentTenant() tenantId: string) {
    return this.poService.findAllCustomers(tenantId);
  }

  @Get('customers/:id')
  @ApiOperation({ summary: 'Get customer details' })
  @ApiResponse({ status: 200, description: 'Customer details' })
  async findOneCustomer(
    @CurrentTenant() tenantId: string,
    @Param('id') customerId: string,
  ) {
    return this.poService.findCustomerById(tenantId, customerId);
  }

  @Put('customers/:id')
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
  @ApiOperation({ summary: 'Create new purchase order' })
  @ApiResponse({ status: 201, description: 'Purchase order created' })
  async createPO(
    @CurrentTenant() tenantId: string,
    @Body() dto: CreatePurchaseOrderDto,
  ) {
    return this.poService.createPurchaseOrder(tenantId, dto);
  }

  @Get('purchase-orders')
  @ApiOperation({ summary: 'List all purchase orders' })
  @ApiResponse({ status: 200, description: 'List of purchase orders' })
  async findAllPOs(@CurrentTenant() tenantId: string) {
    return this.poService.findAllPurchaseOrders(tenantId);
  }

  @Get('purchase-orders/:id')
  @ApiOperation({ summary: 'Get purchase order details' })
  @ApiResponse({ status: 200, description: 'Purchase order details' })
  async findOnePO(
    @CurrentTenant() tenantId: string,
    @Param('id') poId: string,
  ) {
    return this.poService.findOnePurchaseOrder(tenantId, poId);
  }

  @Put('purchase-orders/:id')
  @ApiOperation({ summary: 'Update purchase order' })
  @ApiResponse({ status: 200, description: 'Purchase order updated' })
  async updatePO(
    @CurrentTenant() tenantId: string,
    @Param('id') poId: string,
    @Body() dto: UpdatePurchaseOrderDto,
  ) {
    return this.poService.updatePurchaseOrder(tenantId, poId, dto);
  }

  @Delete('purchase-orders/:id')
  @ApiOperation({ summary: 'Delete purchase order' })
  @ApiResponse({ status: 200, description: 'Purchase order deleted' })
  async removePO(
    @CurrentTenant() tenantId: string,
    @Param('id') poId: string,
  ) {
    return this.poService.removePurchaseOrder(tenantId, poId);
  }
}
