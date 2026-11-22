import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  NotFoundException,
  BadRequestException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import {
  User,
  UserDocument,
  UserAccountStatus,
} from '../../database/schemas/user.schema';
import {
  OtpRecord,
  OtpRecordDocument,
} from '../../database/schemas/otp-record.schema';
import {
  TenantMembership,
  TenantMembershipDocument,
} from '../../database/schemas/tenant-membership.schema';
import { Tenant, TenantDocument } from '../../database/schemas/tenant.schema';
import { EmailService } from '../email/email.service';
import { SignUpDto } from './dtos/sign-up.dto';
import { SignInDto } from './dtos/sign-in.dto';
import { VerifyOtpDto } from './dtos/verify-otp.dto';
import { ForgotPasswordDto } from './dtos/forgot-password.dto';
import { ResetPasswordDto } from './dtos/reset-password.dto';
import { FindUsernamesDto } from './dtos/find-usernames.dto';

@Injectable()
export class AuthService implements OnModuleInit {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @InjectModel(OtpRecord.name)
    private readonly otpModel: Model<OtpRecordDocument>,
    @InjectModel(TenantMembership.name)
    private readonly membershipModel: Model<TenantMembershipDocument>,
    @InjectModel(Tenant.name)
    private readonly tenantModel: Model<TenantDocument>,
    private readonly jwtService: JwtService,
    private readonly emailService: EmailService,
  ) {}

  async onModuleInit() {
    await this.migrateExistingUsers();
  }

  private async migrateExistingUsers() {
    try {
      // 1. Safely drop legacy unique index on email_address if it exists
      await this.userModel.collection.dropIndex('email_address_1').catch(() => {});

      // 2. Assign unique random username to any user missing user_name
      const usersWithoutUsername = await this.userModel.find({
        $or: [
          { user_name: { $exists: false } },
          { user_name: null },
          { user_name: '' },
        ],
      });

      for (const u of usersWithoutUsername) {
        let base = (u.full_name || u.email_address?.split('@')[0] || 'user')
          .toLowerCase()
          .replace(/[^a-z0-9]/g, '');
        if (!base || base.length < 3) base = 'user';

        let candidate = `${base}_${Math.random().toString(36).substring(2, 6)}`;
        while (await this.userModel.exists({ user_name: candidate })) {
          candidate = `user_${Math.random().toString(36).substring(2, 8)}`;
        }

        u.user_name = candidate;
        await u.save();
        this.logger.log(`Migrated user ${u.email_address} to username: ${candidate}`);
      }

      // 3. Ensure unique index on user_name
      await this.userModel.collection
        .createIndex({ user_name: 1 }, { unique: true })
        .catch(() => {});

      // 4. Ensure unique index on membership user_id (1 user in max 1 tenant)
      await this.membershipModel.collection
        .createIndex({ user_id: 1 }, { unique: true })
        .catch(() => {});

      this.logger.log('User and membership migrations completed successfully.');
    } catch (err: any) {
      this.logger.warn(`User migration notice: ${err?.message}`);
    }
  }

  async signUp(dto: SignUpDto) {
    const rawUsername = dto.user_name.trim().toLowerCase();
    const rawEmail = dto.email_address.trim().toLowerCase();

    // Check if username is already taken
    const existingByUsername = await this.userModel.findOne({
      user_name: rawUsername,
    });

    if (existingByUsername) {
      if (existingByUsername.account_status === UserAccountStatus.PENDING_ACTIVATION) {
        // User was pre-added to a tenant by admin; activate and set their password
        const salt = await bcrypt.genSalt(10);
        existingByUsername.password_hash = await bcrypt.hash(dto.password, salt);
        existingByUsername.full_name = dto.full_name;
        existingByUsername.email_address = rawEmail;
        existingByUsername.account_status = UserAccountStatus.ACTIVE;
        await existingByUsername.save();

        const otpCode = await this.generateAndSaveOtp(
          existingByUsername.email_address,
          existingByUsername.user_name,
        );
        await this.emailService.sendOtpEmail(existingByUsername.email_address, otpCode);

        return {
          message:
            'Registration successful. An OTP verification code has been dispatched to your email.',
          user_id: existingByUsername.user_id,
          user_name: existingByUsername.user_name,
          email_address: existingByUsername.email_address,
        };
      }

      throw new ConflictException('Username is already taken. Please choose another username.');
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    const newUser = new this.userModel({
      user_id: uuidv4(),
      user_name: rawUsername,
      full_name: dto.full_name,
      email_address: rawEmail,
      password_hash: passwordHash,
      account_status: UserAccountStatus.ACTIVE,
    });

    await newUser.save();

    // Generate and send OTP for verification (pass both email and unique username)
    try {
      const otpCode = await this.generateAndSaveOtp(newUser.email_address, newUser.user_name);
      await this.emailService.sendOtpEmail(newUser.email_address, otpCode);
    } catch (_) {}

    return {
      message: 'Registration successful.',
      email_address: newUser.email_address,
      user_name: newUser.user_name,
      user_id: newUser.user_id,
    };
  }

  async signIn(dto: SignInDto) {
    const rawUsername = dto.user_name?.trim().toLowerCase();
    const rawEmail = dto.email_address?.trim().toLowerCase();
    const identifier = rawUsername || rawEmail;

    if (!identifier) {
      throw new UnauthorizedException('Username is required to sign in');
    }

    let user: UserDocument | null = null;
    // 1. If username was provided or identifier has no '@', find strictly by unique user_name
    if (rawUsername || !identifier.includes('@')) {
      const usernameToFind = rawUsername || identifier;
      user = await this.userModel.findOne({ user_name: usernameToFind });
    } else {
      // 2. Identifier is an email address: ensure unambiguous account match
      const matchingUsers = await this.userModel.find({ email_address: identifier });
      if (matchingUsers.length === 1) {
        user = matchingUsers[0];
      } else if (matchingUsers.length > 1) {
        throw new UnauthorizedException(
          'Multiple accounts share this email address. Please sign in using your unique Username.',
        );
      }
    }

    if (!user) {
      throw new UnauthorizedException('Invalid username or password');
    }

    const isPasswordValid = await bcrypt.compare(
      dto.password,
      user.password_hash,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid username or password');
    }

    if (user.account_status !== UserAccountStatus.ACTIVE) {
      throw new UnauthorizedException(
        `Account is ${user.account_status.toLowerCase()}`,
      );
    }

    // Temporary OTP Skip: Directly issue JWT Token and return session
    const payload = {
      sub: user.user_id,
      email: user.email_address,
      full_name: user.full_name,
    };
    const accessToken = this.jwtService.sign(payload);

    // Fetch active memberships and tenants
    const memberships = await this.membershipModel.find({
      user_id: user.user_id,
      is_active: true,
    });

    const tenantIds = memberships.map((m) => m.tenant_id);
    const tenants = await this.tenantModel.find({
      $or: [
        { tenant_id: { $in: tenantIds } },
        { admin_user_id: user.user_id },
      ],
      is_active: true,
    });

    return {
      message: 'Sign in successful (OTP temporarily skipped).',
      access_token: accessToken,
      requires_otp: false,
      user: {
        user_id: user.user_id,
        user_name: user.user_name,
        full_name: user.full_name,
        email_address: user.email_address,
        department_id: user.department_id,
        avatar_url: user.avatar_url || null,
        phone_number: user.phone_number || null,
      },
      available_tenants: tenants.map((t) => {
        const mem = memberships.find((m) => m.tenant_id === t.tenant_id);
        const isAdmin = t.admin_user_id === user.user_id;
        return {
          tenant_id: t.tenant_id,
          company_name: t.company_name,
          is_admin: isAdmin,
          has_all_departments_access: isAdmin,
          department_ids: mem?.department_ids || [],
        };
      }),
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const rawUsername = dto.user_name?.trim().toLowerCase();
    const rawEmail = dto.email_address?.trim().toLowerCase();

    let user: UserDocument | null = null;
    if (rawUsername) {
      user = await this.userModel.findOne({ user_name: rawUsername });
    } else if (rawEmail) {
      const matchingUsers = await this.userModel.find({ email_address: rawEmail });
      if (matchingUsers.length === 1) {
        user = matchingUsers[0];
      } else if (matchingUsers.length > 1) {
        throw new BadRequestException(
          'Multiple accounts share this email address. Please verify using your unique Username.',
        );
      }
    }

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Mark OTP as verified if found, or bypass if skipped temporarily
    const otpRecord = await this.otpModel
      .findOne({
        $or: [
          ...(user.user_name ? [{ user_name: user.user_name }] : []),
          { email_address: user.email_address },
        ],
        is_verified: false,
      })
      .sort({ created_at: -1 });

    if (otpRecord) {
      otpRecord.is_verified = true;
      await otpRecord.save();
    }

    // Issue JWT Token
    const payload = { sub: user.user_id, email: user.email_address };
    const accessToken = this.jwtService.sign(payload);

    // Fetch all active tenants the user belongs to (for the tenant selector screen)
    const memberships = await this.membershipModel.find({
      user_id: user.user_id,
      is_active: true,
    });

    const tenantIds = memberships.map((m) => m.tenant_id);
    const tenants = await this.tenantModel.find({
      tenant_id: { $in: tenantIds },
      is_active: true,
    });

    return {
      access_token: accessToken,
      user: {
        user_id: user.user_id,
        user_name: user.user_name,
        full_name: user.full_name,
        email_address: user.email_address,
        department_id: user.department_id,
        avatar_url: user.avatar_url || null,
        phone_number: user.phone_number || null,
      },
      available_tenants: tenants.map((t) => {
        const mem = memberships.find((m) => m.tenant_id === t.tenant_id);
        const isAdmin = t.admin_user_id === user.user_id;
        return {
          tenant_id: t.tenant_id,
          company_name: t.company_name,
          is_admin: isAdmin,
          has_all_departments_access: isAdmin,
          department_ids: mem?.department_ids || [],
        };
      }),
    };
  }

  async resendOtp(emailAddress: string) {
    const user = await this.userModel.findOne({
      email_address: emailAddress.toLowerCase(),
    });

    if (!user) {
      throw new NotFoundException('Account with this email does not exist');
    }

    const otpCode = await this.generateAndSaveOtp(user.email_address);
    await this.emailService.sendOtpEmail(user.email_address, otpCode);

    return {
      message: 'A new OTP has been sent to your email address.',
      email_address: user.email_address,
    };
  }

  async findUsernamesByEmail(dto: FindUsernamesDto) {
    const email = dto.email_address?.toLowerCase().trim();
    if (!email) {
      throw new BadRequestException('Email address is required');
    }

    const users = await this.userModel
      .find({
        email_address: email,
        account_status: { $ne: UserAccountStatus.SUSPENDED },
      })
      .select('user_name full_name account_status created_at')
      .exec();

    if (!users || users.length === 0) {
      throw new NotFoundException('No active accounts found for this email address');
    }

    const usernames = users.map((u) => u.user_name);
    try {
      await this.emailService.sendUsernamesReminderEmail(email, usernames);
    } catch (_) {}

    return {
      message: `Found ${users.length} username(s) associated with this email address.`,
      email_address: email,
      count: users.length,
      usernames,
      users: users.map((u) => ({
        user_name: u.user_name,
        full_name: u.full_name,
        account_status: u.account_status,
      })),
    };
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const rawUsername = dto.user_name?.trim().toLowerCase();
    const rawEmail = dto.email_address?.trim().toLowerCase();

    let user: UserDocument | null = null;

    if (rawUsername) {
      user = await this.userModel.findOne({ user_name: rawUsername });
      if (!user) {
        throw new NotFoundException(`No account found with username "${dto.user_name}"`);
      }
    } else if (rawEmail) {
      const matchingUsers = await this.userModel.find({ email_address: rawEmail });
      if (matchingUsers.length === 0) {
        throw new NotFoundException('No account found with this email address');
      }
      if (matchingUsers.length > 1) {
        throw new BadRequestException(
          'Multiple accounts share this email address. Please provide your username or use "Find Usernames".',
        );
      }
      user = matchingUsers[0];
    } else {
      throw new BadRequestException('Username is required to request a password reset');
    }

    if (user.account_status !== UserAccountStatus.ACTIVE) {
      throw new UnauthorizedException(`Account is ${user.account_status.toLowerCase()}`);
    }

    const otpCode = await this.generateAndSaveOtp(user.email_address, user.user_name);
    await this.emailService.sendPasswordResetOtpEmail(user.email_address, otpCode, user.user_name);

    // Mask email for user hint & privacy: j***e@domain.com
    let maskedEmail = user.email_address;
    const parts = user.email_address.split('@');
    if (parts.length === 2) {
      const local = parts[0];
      const domain = parts[1];
      const maskedLocal =
        local.length > 2
          ? `${local[0]}***${local[local.length - 1]}`
          : `${local[0]}*`;
      maskedEmail = `${maskedLocal}@${domain}`;
    }

    return {
      message: `Password reset verification code has been sent to the email address registered with username "${user.user_name}".`,
      user_name: user.user_name,
      email_address: user.email_address,
      masked_email: maskedEmail,
    };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const rawUsername = dto.user_name?.trim().toLowerCase();
    const rawEmail = dto.email_address?.trim().toLowerCase();

    let user: UserDocument | null = null;

    if (rawUsername) {
      user = await this.userModel.findOne({ user_name: rawUsername });
      if (!user) {
        throw new NotFoundException(`Account with username "${dto.user_name}" not found`);
      }
    } else if (rawEmail) {
      const matchingUsers = await this.userModel.find({ email_address: rawEmail });
      if (matchingUsers.length === 0) {
        throw new NotFoundException('Account not found');
      }
      if (matchingUsers.length > 1) {
        throw new BadRequestException(
          'Multiple accounts share this email address. Please specify your username.',
        );
      }
      user = matchingUsers[0];
    } else {
      throw new BadRequestException('Username is required to reset password');
    }

    // Match unexpired OTP code for this user by user_name or email_address
    const otpQuery: any = {
      otp_code: dto.otp_code.trim(),
      expires_at: { $gt: new Date() },
      is_verified: false,
    };

    if (user.user_name) {
      otpQuery.$or = [
        { user_name: user.user_name },
        { email_address: user.email_address },
      ];
    } else {
      otpQuery.email_address = user.email_address;
    }

    const otpRecord = await this.otpModel
      .findOne(otpQuery)
      .sort({ created_at: -1 });

    if (!otpRecord) {
      throw new UnauthorizedException('Invalid or expired OTP verification code');
    }

    // Mark as verified
    otpRecord.is_verified = true;
    await otpRecord.save();

    // Hash the new password
    const saltRounds = 10;
    const newPasswordHash = await bcrypt.hash(dto.new_password, saltRounds);

    user.password_hash = newPasswordHash;
    await user.save();

    return {
      message: 'Password has been reset successfully. You can now sign in with your new password.',
      user_name: user.user_name,
      email_address: user.email_address,
    };
  }

  private async generateAndSaveOtp(email: string, userName?: string): Promise<string> {
    // 6-digit cryptographic random OTP code
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await this.otpModel.create({
      record_id: uuidv4(),
      user_name: userName ? userName.toLowerCase().trim() : undefined,
      email_address: email.toLowerCase(),
      otp_code: otpCode,
      expires_at: expiresAt,
      is_verified: false,
    });

    return otpCode;
  }
}

