export default () => ({
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  database: {
    uri:
      process.env.MONGODB_URI ||
      'mongodb://127.0.0.1:27017/cpms_database',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'cpms_default_secret_key_change_in_prod',
    expiresIn: process.env.JWT_EXPIRATION_TIME || '7d',
  },
  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    fromName: process.env.SMTP_FROM_NAME || 'CPMS Platform',
    fromEmail: process.env.SMTP_FROM_EMAIL || 'no-reply@cpms.local',
  },
  aws: {
    s3Bucket: process.env.AWS_S3_BUCKET || '',
    region: process.env.AWS_REGION || 'us-east-1',
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
    endpoint: process.env.AWS_S3_ENDPOINT || undefined,
    publicUrlPrefix: process.env.AWS_S3_PUBLIC_URL_PREFIX || '',
  },
});

