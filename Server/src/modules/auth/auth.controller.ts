import {
  Controller,
  Post,
  Body,
  Get,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiBody,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { SignUpDto } from './dtos/sign-up.dto';
import { SignInDto } from './dtos/sign-in.dto';
import { VerifyOtpDto } from './dtos/verify-otp.dto';
import { ForgotPasswordDto } from './dtos/forgot-password.dto';
import { ResetPasswordDto } from './dtos/reset-password.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('sign-up')
  @ApiOperation({
    summary: 'Register new user',
    description: 'Registers account, hashes password, and dispatches a 6-digit OTP code to email via Nodemailer.',
  })
  @ApiResponse({ status: 201, description: 'User registered, OTP dispatched' })
  @ApiResponse({ status: 409, description: 'Email address already exists' })
  async signUp(@Body() dto: SignUpDto) {
    return this.authService.signUp(dto);
  }

  @Post('sign-in')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Sign in with credentials',
    description: 'Validates email & password, then dispatches an OTP verification code.',
  })
  @ApiResponse({ status: 200, description: 'Credentials verified, OTP dispatched' })
  @ApiResponse({ status: 401, description: 'Invalid email or password' })
  async signIn(@Body() dto: SignInDto) {
    return this.authService.signIn(dto);
  }

  @Post('verify-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Verify OTP and get JWT',
    description: 'Verifies the 6-digit OTP, issues a JWT Bearer token, and returns available tenant memberships.',
  })
  @ApiResponse({
    status: 200,
    description: 'OTP verified. Returns access_token and available_tenants array.',
  })
  @ApiResponse({ status: 401, description: 'Invalid or expired OTP code' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('resend-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Resend new OTP code to email' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: { email_address: { type: 'string', example: 'john.doe@example.com' } },
      required: ['email_address'],
    },
  })
  async resendOtp(@Body('email_address') emailAddress: string) {
    return this.authService.resendOtp(emailAddress);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Request password reset OTP',
    description: 'Generates a 6-digit password reset OTP and emails it to the user.',
  })
  @ApiResponse({ status: 200, description: 'Reset OTP dispatched to email' })
  @ApiResponse({ status: 404, description: 'Email address not registered' })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Verify OTP and set new password',
    description: 'Verifies the 6-digit OTP code and updates the account password.',
  })
  @ApiResponse({ status: 200, description: 'Password reset successfully' })
  @ApiResponse({ status: 401, description: 'Invalid or expired OTP code' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('jwt-auth')
  @ApiOperation({ summary: 'Get authenticated user profile' })
  @ApiResponse({ status: 200, description: 'Profile of authenticated user' })
  async getProfile(@CurrentUser() user: any) {
    return user;
  }
}
