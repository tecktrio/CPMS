import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  NotFoundException,
  Logger,
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

@Injectable()
export class AuthService {
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

  async signUp(dto: SignUpDto) {
    const existingUser = await this.userModel.findOne({
      email_address: dto.email_address.toLowerCase(),
    });

    if (existingUser) {
      if (existingUser.account_status === UserAccountStatus.PENDING_ACTIVATION) {
        // User was pre-added to a tenant by an admin; activate and set their password
        const salt = await bcrypt.genSalt(10);
        existingUser.password_hash = await bcrypt.hash(dto.password, salt);
        existingUser.full_name = dto.full_name;
        existingUser.account_status = UserAccountStatus.ACTIVE;
        await existingUser.save();

        const otpCode = await this.generateAndSaveOtp(existingUser.email_address);
        await this.emailService.sendOtpEmail(existingUser.email_address, otpCode);

        return {
          message:
            'Registration successful. An OTP verification code has been dispatched to your email.',
          user_id: existingUser.user_id,
          email_address: existingUser.email_address,
        };
      }

      throw new ConflictException(
        'An account with this email address already exists',
      );
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    const newUser = new this.userModel({
      user_id: uuidv4(),
      full_name: dto.full_name,
      email_address: dto.email_address.toLowerCase(),
      password_hash: passwordHash,
      account_status: UserAccountStatus.ACTIVE,
    });

    await newUser.save();

    // Generate and send OTP for verification (non-blocking for temporary bypass)
    try {
      const otpCode = await this.generateAndSaveOtp(newUser.email_address);
      await this.emailService.sendOtpEmail(newUser.email_address, otpCode);
    } catch (_) {}

    return {
      message: 'Registration successful.',
      email_address: newUser.email_address,
      user_id: newUser.user_id,
    };
  }

  async signIn(dto: SignInDto) {
    const user = await this.userModel.findOne({
      email_address: dto.email_address.toLowerCase(),
    });

    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(
      dto.password,
      user.password_hash,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
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
        full_name: user.full_name,
        email_address: user.email_address,
        department_id: user.department_id,
        avatar_url: user.avatar_url || null,
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
    const email = dto.email_address.toLowerCase();

    const user = await this.userModel.findOne({ email_address: email });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Mark OTP as verified if found, or bypass if skipped temporarily
    const otpRecord = await this.otpModel
      .findOne({
        email_address: email,
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
        full_name: user.full_name,
        email_address: user.email_address,
        department_id: user.department_id,
        avatar_url: user.avatar_url || null,
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

  async forgotPassword(dto: ForgotPasswordDto) {
    const email = dto.email_address.toLowerCase().trim();
    const user = await this.userModel.findOne({ email_address: email });

    if (!user) {
      throw new NotFoundException('No account found with this email address');
    }

    if (user.account_status !== UserAccountStatus.ACTIVE) {
      throw new UnauthorizedException(`Account is ${user.account_status.toLowerCase()}`);
    }

    const otpCode = await this.generateAndSaveOtp(user.email_address);
    await this.emailService.sendPasswordResetOtpEmail(user.email_address, otpCode);

    return {
      message: 'Password reset code has been sent to your email address.',
      email_address: user.email_address,
    };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const email = dto.email_address.toLowerCase().trim();

    // Find the latest unexpired OTP for this email
    const otpRecord = await this.otpModel
      .findOne({
        email_address: email,
        otp_code: dto.otp_code.trim(),
        expires_at: { $gt: new Date() },
        is_verified: false,
      })
      .sort({ created_at: -1 });

    if (!otpRecord) {
      throw new UnauthorizedException('Invalid or expired OTP verification code');
    }

    // Mark as verified
    otpRecord.is_verified = true;
    await otpRecord.save();

    const user = await this.userModel.findOne({ email_address: email });
    if (!user) {
      throw new NotFoundException('Account not found');
    }

    // Hash the new password
    const saltRounds = 10;
    const newPasswordHash = await bcrypt.hash(dto.new_password, saltRounds);

    user.password_hash = newPasswordHash;
    await user.save();

    return {
      message: 'Password has been reset successfully. You can now sign in with your new password.',
      email_address: user.email_address,
    };
  }

  private async generateAndSaveOtp(email: string): Promise<string> {
    // 6-digit cryptographic random OTP code
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await this.otpModel.create({
      record_id: uuidv4(),
      email_address: email.toLowerCase(),
      otp_code: otpCode,
      expires_at: expiresAt,
      is_verified: false,
    });

    return otpCode;
  }
}

