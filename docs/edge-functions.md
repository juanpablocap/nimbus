# Nimbus — Edge Functions (QR System)

## Overview

The QR access system runs on Supabase Edge Functions (Deno). Three functions handle the full lifecycle:

1. **generate-qr** — Creates a signed JWT token for a visit
2. **validate-qr** — Validates a scanned QR token
3. **confirm-access** — Approves entry and registers it in access_logs

---

## Architecture

```
Resident creates visit → generate-qr → JWT token saved to visits.qr_token
                                       ↓
                              QR rendered in mobile app (qr_flutter)
                                       ↓
Guard scans QR → validate-qr → checks JWT signature, expiry, usage, status
                                       ↓
                              Guard sees visitor details on screen
                                       ↓
Guard taps "Approve" → confirm-access → creates access_log + increments times_used
```

---

## Functions

### generate-qr

**POST** `/functions/v1/generate-qr`

**Auth:** Required (resident's JWT in Authorization header)

**Body:**
```json
{ "visit_id": "uuid" }
```

**Logic:**
1. Verify user is authenticated
2. Fetch visit, verify ownership (created_by === user.id)
3. Verify visit is active
4. Generate HMAC-SHA256 signed JWT with visit data
5. Save token to visits.qr_token
6. Return token + visit metadata

**Response:**
```json
{
  "qr_token": "eyJ...",
  "visit_id": "...",
  "visitor_name": "...",
  "property_name": "...",
  "expires_at": "...",
  "max_uses": 1,
  "times_used": 0
}
```

### validate-qr

**POST** `/functions/v1/validate-qr`

**Auth:** Required (guard's JWT)

**Body:**
```json
{ "qr_token": "eyJ..." }
```

**Logic:**
1. Verify guard is authenticated
2. Verify JWT signature and expiration
3. Fetch visit from database
4. Check: status === active, times_used < max_uses, not expired
5. Verify guard belongs to same community as visit
6. Return visit details for guard confirmation

**Response (valid):**
```json
{
  "valid": true,
  "visit": {
    "id": "...",
    "visitor_name": "...",
    "visitor_document": "...",
    "property": { "name": "...", "address": "..." },
    "resident": { "name": "...", "phone": "..." },
    "times_used": 0,
    "max_uses": 1
  }
}
```

**Response (invalid):**
```json
{
  "valid": false,
  "reason": "expired|inactive|max_uses_reached|wrong_community|invalid",
  "message": "Human-readable explanation"
}
```

### confirm-access

**POST** `/functions/v1/confirm-access`

**Auth:** Required (guard's JWT)

**Body:**
```json
{
  "visit_id": "uuid",
  "action": "entry",
  "notes": "optional"
}
```

**Logic:**
1. Verify guard is authenticated
2. Fetch visit, verify it's active and within usage limits
3. Insert row into access_logs
4. Increment visits.times_used
5. If times_used >= max_uses, set status to "used"

---

## Environment Variables

Required in Supabase Edge Functions settings:

- `QR_JWT_SECRET` — Secret key for signing QR tokens (HMAC-SHA256)
- `SUPABASE_URL` — Auto-provided by Supabase
- `SUPABASE_SERVICE_ROLE_KEY` — Auto-provided by Supabase
- `SUPABASE_ANON_KEY` — Auto-provided by Supabase

---

## Deployment

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link project
supabase link --project-ref yxdwshujxsnamnmllljc

# Deploy all functions
supabase functions deploy generate-qr
supabase functions deploy validate-qr
supabase functions deploy confirm-access

# Set secret
supabase secrets set QR_JWT_SECRET=your-secret-here
```

---

## Security

- All functions require authentication (JWT in Authorization header)
- QR tokens are HMAC-SHA256 signed, tamper-proof
- generate-qr verifies ownership (only the visit creator can generate)
- validate-qr verifies community match (guards can't validate visits from other communities)
- confirm-access verifies visit is still active before registering
- Tokens have time-based expiration (valid_until) AND usage limits (max_uses)

