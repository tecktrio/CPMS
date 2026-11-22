import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private readonly configService: ConfigService) {
    const smtp = this.configService.get('smtp');
    this.transporter = nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.secure,
      auth: {
        user: smtp.user,
        pass: smtp.pass,
      },
    });
  }

  async sendOtpEmail(toEmail: string, otpCode: string): Promise<boolean> {
    const smtp = this.configService.get('smtp');

    const mailOptions = {
      from: `"${smtp.fromName}" <${smtp.fromEmail}>`,
      to: toEmail,
      subject: 'Your CPMS Verification Code',
      text: `Your verification OTP is: ${otpCode}. This code will expire in 10 minutes.`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #0070f3; text-align: center;">CPMS Verification Code</h2>
          <p>Hello,</p>
          <p>Please use the verification code below to complete your authentication request:</p>
          <div style="text-align: center; margin: 25px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #111; background: #f4f6f8; padding: 10px 20px; border-radius: 6px; display: inline-block;">${otpCode}</span>
          </div>
          <p style="color: #666; font-size: 13px;">This code will expire in 10 minutes. If you did not make this request, please disregard this email.</p>
        </div>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      this.logger.log(`OTP successfully emailed to ${toEmail}`);
      return true;
    } catch (error) {
      this.logger.warn(
        `Nodemailer SMTP dispatch failed: ${(error as Error).message}`,
      );
      // Dev fallback: output prominently so development & testing can continue smoothly
      this.logger.log(`====================================================`);
      this.logger.log(`[DEV OTP FALLBACK] Recipient: ${toEmail}`);
      this.logger.log(`[DEV OTP FALLBACK] Verification Code: ${otpCode}`);
      this.logger.log(`====================================================`);
      return false;
    }
  }

  async sendPasswordResetOtpEmail(
    toEmail: string,
    otpCode: string,
    userName?: string,
  ): Promise<boolean> {
    const smtp = this.configService.get('smtp');

    const greeting = userName ? `Hello <strong>${userName}</strong>,` : 'Hello,';
    const accountNotice = userName
      ? `We received a request to reset the password for your CPMS account with username <strong>${userName}</strong>.`
      : `We received a request to reset the password for your CPMS account.`;

    const mailOptions = {
      from: `"${smtp.fromName}" <${smtp.fromEmail}>`,
      to: toEmail,
      subject: `CPMS - Password Reset Request${userName ? ` (${userName})` : ''}`,
      text: `Your password reset code for CPMS account (${userName || 'user'}) is: ${otpCode}. This code will expire in 10 minutes.`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #0F766E; text-align: center;">Reset Your Password</h2>
          <p>${greeting}</p>
          <p>${accountNotice} Please use the verification code below to proceed:</p>
          <div style="text-align: center; margin: 25px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #0F766E; background: #f0fdfa; padding: 10px 20px; border-radius: 6px; display: inline-block; border: 1px solid #99f6e4;">${otpCode}</span>
          </div>
          <p style="color: #666; font-size: 13px;">This code will expire in 10 minutes. If you did not request a password reset, you can safely ignore this email.</p>
        </div>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      this.logger.log(`Password reset OTP successfully emailed to ${toEmail}`);
      return true;
    } catch (error) {
      this.logger.warn(
        `Nodemailer SMTP dispatch failed: ${(error as Error).message}`,
      );
      this.logger.log(`====================================================`);
      this.logger.log(`[DEV RESET OTP FALLBACK] Recipient: ${toEmail}`);
      if (userName) {
        this.logger.log(`[DEV RESET OTP FALLBACK] Username: ${userName}`);
      }
      this.logger.log(`[DEV RESET OTP FALLBACK] Reset Code: ${otpCode}`);
      this.logger.log(`====================================================`);
      return false;
    }
  }

  async sendUsernamesReminderEmail(
    toEmail: string,
    usernames: string[],
  ): Promise<boolean> {
    const smtp = this.configService.get('smtp');

    const usernameListHtml = usernames
      .map(
        (u) =>
          `<li style="padding: 6px 0; font-size: 15px; font-weight: bold; color: #0F172A;">${u}</li>`,
      )
      .join('');

    const mailOptions = {
      from: `"${smtp.fromName}" <${smtp.fromEmail}>`,
      to: toEmail,
      subject: 'CPMS - Your Assigned Usernames',
      text: `Here are the usernames assigned to your email (${toEmail}):\n${usernames.join('\n')}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #0F766E; text-align: center;">Your CPMS Usernames</h2>
          <p>Hello,</p>
          <p>We received a request to look up the username(s) associated with this email address:</p>
          <ul style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 16px 30px;">
            ${usernameListHtml}
          </ul>
          <p style="color: #666; font-size: 13px;">If you need to reset your password, please use one of the usernames above on the Reset Password screen.</p>
        </div>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      this.logger.log(`Usernames reminder successfully emailed to ${toEmail}`);
      return true;
    } catch (error) {
      this.logger.warn(
        `Nodemailer SMTP dispatch failed: ${(error as Error).message}`,
      );
      this.logger.log(`====================================================`);
      this.logger.log(`[DEV USERNAMES FALLBACK] Recipient: ${toEmail}`);
      this.logger.log(`[DEV USERNAMES FALLBACK] Usernames: ${usernames.join(', ')}`);
      this.logger.log(`====================================================`);
      return false;
    }
  }
}

