import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;
    if (data === 'id') return user?.id ?? user?.user_id;
    if (data === 'user_id') return user?.user_id ?? user?.id;
    return data ? user?.[data] : user;
  },
);

