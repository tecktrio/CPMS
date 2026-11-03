import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  User,
  UserDocument,
  UserAccountStatus,
} from '../../../database/schemas/user.schema';

export interface JwtPayload {
  sub: string;
  email: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private readonly configService: ConfigService,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.secret'),
    });
  }

  async validate(payload: JwtPayload) {
    const user = await this.userModel.findOne({ user_id: payload.sub });

    if (!user) {
      throw new UnauthorizedException('User account no longer exists');
    }

    if (user.account_status !== UserAccountStatus.ACTIVE) {
      throw new UnauthorizedException(
        `Account is currently ${user.account_status.toLowerCase()}`,
      );
    }

    return {
      user_id: user.user_id,
      email_address: user.email_address,
      full_name: user.full_name,
      department_id: user.department_id,
      account_status: user.account_status,
    };
  }
}

