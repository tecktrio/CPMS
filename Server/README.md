# CIMS Backend (NestJS + MongoDB Atlas)

Clean architecture backend for the **Cyan International Management System (CIMS)** food production and cold room inventory platform.

---

## 🏛️ Architecture Overview

The backend uses standard NestJS modular architecture with clear domain separation and clean, human-readable naming:

```
src/
├── main.ts                          # Bootstrap with CORS, validation pipe & filters
├── app.module.ts                    # Root module registering all domain features
├── config/
│   └── configuration.ts             # Type-safe environment configuration loader
├── common/
│   ├── decorators/
│   │   ├── current-user.decorator.ts    # Extracts authenticated user from JWT
│   │   └── current-tenant.decorator.ts  # Extracts validated X-Tenant-ID
│   ├── guards/
│   │   ├── jwt-auth.guard.ts        # Passport JWT bearer authentication guard
│   │   └── tenant.guard.ts          # Validates user's active membership in X-Tenant-ID
│   ├── filters/
│   │   └── http-exception.filter.ts # Unified error response structure
│   └── interceptors/
│       └── transform-response.interceptor.ts # Unified { success: true, data: ... } wrapper
├── database/
│   ├── database.module.ts           # Mongoose async connection (Atlas / local)
│   └── schemas/
│       ├── user.schema.ts           # Users entity (UUIDv4)
│       ├── tenant.schema.ts         # Tenants entity (UUIDv4)
│       ├── tenant-membership.schema.ts # TenantMemberships mapping
│       ├── store-room.schema.ts     # StoreRooms (cold room capacity & temp)
│       ├── item.schema.ts           # Item (SKU, measurement unit, reorder threshold)
│       ├── stock-batch.schema.ts    # StockBatch (FEFO expiry tracking & location)
│       └── otp-record.schema.ts     # OTP records with TTL auto-cleanup
└── modules/
    ├── email/                       # Nodemailer service with dev terminal fallback
    ├── auth/                        # Registration, Sign-in, OTP verification, JWT
    ├── tenants/                     # Tenant creation, multi-tenant selector, invitations
    ├── users/                       # User directory within tenant
    ├── store-rooms/                 # Cold room CRUD with live capacity checks
    ├── items/                       # Item catalog with reorder threshold alerts
    └── stock-batches/               # Inward batch receipt & FEFO allocation engine (Option B)
```

---

## 🚀 Quick Start

### 1. Configure Environment
Copy `.env.example` to `.env` and provide your MongoDB Atlas connection URI:
```bash
cp .env.example .env
```

Edit `.env`:
```env
PORT=3000
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/cims_database?retryWrites=true&w=majority
JWT_SECRET=your_jwt_secret_key_here
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password
```

> **Note for Local Testing**: If SMTP credentials are left as placeholders, the server will automatically print the 6-digit OTP code in the terminal so you can test sign-up and login without real email credentials.

### 2. Install & Run
```bash
npm install
npm run start:dev
```

The API will be available at: `http://localhost:3000/api/v1`

---

## 📡 Phase 1 API Endpoints

### 🔐 Authentication (`/api/v1/auth`)
- `POST /auth/sign-up` — Register with name, email, password $\rightarrow$ sends OTP
- `POST /auth/sign-in` — Validate email & password $\rightarrow$ sends OTP
- `POST /auth/verify-otp` — Verify 6-digit code $\rightarrow$ returns JWT + available tenants
- `POST /auth/resend-otp` — Generate and send a new OTP
- `GET  /auth/me` — Authenticated user profile

### 🏢 Tenants (`/api/v1/tenants`)
*Requires Bearer Token*
- `POST /tenants` — Create new organization (creator automatically becomes admin)
- `GET  /tenants` — List organizations the user belongs to (powers mobile Tenant Selector)
- `GET  /tenants/:id` — Get organization details
- `POST /tenants/invite` — Tenant admin invites a user by email & assigns department

### ❄️ Cold Rooms (`/api/v1/store-rooms`)
*Requires Bearer Token & `X-Tenant-ID: <UUID>` header*
- `GET    /store-rooms` — List cold rooms with live capacity utilization %
- `GET    /store-rooms/:id` — Room details & active batch count
- `POST   /store-rooms` — Create store room (enforces unique room code per tenant)
- `PUT    /store-rooms/:id` — Update room (prevents reducing capacity below current stock)
- `DELETE /store-rooms/:id` — Deactivate room (blocks if active batches exist)

### 📦 Items & Raw Materials (`/api/v1/items`)
*Requires Bearer Token & `X-Tenant-ID: <UUID>` header*
- `GET    /items` — List items with current stock count & reorder shortfall alerts
- `GET    /items/:id` — Item details with active batches sorted by FEFO
- `POST   /items` — Create item (enforces unique SKU per tenant)
- `PUT    /items/:id` — Update item properties
- `DELETE /items/:id` — Delete item (blocks if active stock batches exist)

### 🏷️ Stock Batches & FEFO Engine (`/api/v1/stock-batches`)
*Requires Bearer Token & `X-Tenant-ID: <UUID>` header*
- `POST /stock-batches` — Inward batch receipt (checks cold room capacity limit!)
- `GET  /stock-batches` — List batches (filters: `?itemId=...&storeRoomId=...&status=...`)
- `GET  /stock-batches/expiring-soon?days=7` — Batches expiring within next N days
- `POST /stock-batches/suggest-fefo` — Suggests batches to pick based on FEFO
- `POST /stock-batches/deduct-batches` — Operator-confirmed stock deduction (Option B)

