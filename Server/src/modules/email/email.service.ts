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
      subject: 'Your CIMS Verification Code',
      text: `Your verification OTP is: ${otpCode}. This code will expire in 10 minutes.`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #0070f3; text-align: center;">CIMS Verification Code</h2>
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
}

