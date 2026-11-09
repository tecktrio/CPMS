import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiHeader,
  ApiConsumes,
} from '@nestjs/swagger';
import { UsersService } from './users.service';
import { StorageService } from '../storage/storage.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantGuard } from '../../common/guards/tenant.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import {
  RequirePermissions,
  RequireAnyPermissions,
} from '../../common/decorators/require-permissions.decorator';
import { CurrentTenant } from '../../common/decorators/current-tenant.decorator';

@ApiTags('Users Directory')
@ApiBearerAuth('jwt-auth')
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly storageService: StorageService,
  ) {}

  @Put('profile')
  @ApiOperation({
    summary: 'Update current user personal profile',
    description: 'Updates full name and/or phone number of the authenticated user.',
  })
  @ApiResponse({ status: 200, description: 'Profile updated successfully' })
  async updateProfile(
    @CurrentUser('user_id') userId: string,
    @Body() body: { full_name?: string; phone_number?: string },
  ) {
    return this.usersService.updateProfile(userId, body);
  }

  @Post('avatar')
  @UseInterceptors(FileInterceptor('image'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload user profile picture',
    description: 'Uploads avatar image to AWS S3 (or fallback storage) and updates the current user account, replacing the previous image on S3.',
  })
  @ApiResponse({ status: 200, description: 'Profile picture updated successfully' })
  async uploadAvatar(
    @CurrentUser('user_id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const avatarUrl = await this.storageService.uploadFile(file, 'avatars');
    return this.usersService.updateAvatar(userId, avatarUrl);
  }

  @Delete('avatar')
  @ApiOperation({
    summary: 'Remove user profile picture',
    description: 'Deletes user avatar from S3 and sets avatar_url to null.',
  })
  @ApiResponse({ status: 200, description: 'Profile picture removed successfully' })
  async removeAvatar(@CurrentUser('user_id') userId: string) {
    return this.usersService.removeAvatar(userId);
  }

  @Get()
  @UseGuards(TenantGuard, PermissionsGuard)
  @RequireAnyPermissions(
    'permission.user.read',
    'permission.user.add',
    'permission.user.update',
    'permission.user.delete',
    'permission.department.read',
    'permission.department.create',
    'permission.department.update',
    'permission.department.delete',
  )
  @ApiHeader({
    name: 'X-Tenant-ID',
    description: 'Active tenant UUID',
    required: true,
  })
  @ApiOperation({
    summary: 'List users in active tenant',
    description: 'Returns all users having active memberships in the specified organization. Requires permission.user.read.',
  })
  @ApiResponse({ status: 200, description: 'List of tenant users' })
  @ApiResponse({ status: 403, description: 'Forbidden - Missing required permission' })
  async findAllInTenant(@CurrentTenant() tenantId: string) {
    return this.usersService.findAllInTenant(tenantId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user profile by user_id' })
  @ApiResponse({ status: 200, description: 'User profile' })
  async findOne(@Param('id') userId: string) {
    return this.usersService.findOne(userId);
  }
}
