export default () => ({
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  database: {
    uri:
      process.env.MONGODB_URI ||
      'mongodb://127.0.0.1:27017/cims_database',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'cims_default_secret_key_change_in_prod',
    expiresIn: process.env.JWT_EXPIRATION_TIME || '7d',
  },
  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    fromName: process.env.SMTP_FROM_NAME || 'CIMS Platform',
    fromEmail: process.env.SMTP_FROM_EMAIL || 'no-reply@cims.local',
  },
});

