# NIMBUS — Contexto del Proyecto

> Documento de referencia para Claude. Se actualiza al final de cada sesión de trabajo.

## ¿Qué es Nimbus?

SaaS multi-tenant para barrios privados y countries. Digitaliza administración, comunicación y control de accesos.

**Filosofía:** moderno, premium, rápido, extremadamente simple. Mobile-first.
**Inspiración:** Airbnb, Uber, Mercado Pago, Notion.

## Equipo técnico

- Juan Pablo — producto, tecnología, infraestructura, implementación
- Claude — asistente técnico permanente

## Stack

| Capa | Tecnología |
|---|---|
| Admin web | Next.js 15 + TypeScript + Tailwind CSS |
| Mobile | Flutter (Dart) |
| Backend | Supabase (Auth, DB, Edge Functions, Realtime) |
| Edge Functions | Deno / TypeScript |
| Monorepo | pnpm workspaces |
| Deploy admin | Vercel |
| Deploy functions | Supabase CLI |

## Estructura del repo

```
apps/
  admin/          — Next.js admin panel
  mobile/         — Flutter app
    lib/
      core/       — router, theme, constants
      features/   — auth, home, visits, scanner, news, notifications, profile
supabase/
  functions/
    _shared/      — cors.ts, supabase.ts, qr-jwt.ts, auth.ts
    generate-qr/
    validate-qr/
    confirm-access/
    manual-access/
  migrations/     — SQL migrations
docs/             — arquitectura, stack, DB, roadmap, etc.
```

## Base de datos (tablas principales)

- `communities` — barrios (multi-tenant root)
- `profiles` — usuarios con rol: resident | guard | admin | superadmin
- `properties` — lotes/casas
- `visits` — visitas con QR, status: active | used | expired | cancelled
- `access_logs` — registro de ingresos (method: qr | manual)
- `news` — noticias con `is_published`, `body`, `author_id`
- `notifications` — notificaciones in-app con `is_read`, `type`, `reference_id`

## Edge Functions

| Función | Descripción |
|---|---|
| `generate-qr` | Residente genera token JWT firmado para visita |
| `validate-qr` | Guardia escanea y valida QR (verifica firma + DB) |
| `confirm-access` | Guardia confirma ingreso — requiere `qr_token` + rol guard |
| `manual-access` | Guardia registra acceso manual sin QR |

## Estado del MVP

### ✅ Completado
- Auth (login, sesión, roles)
- Admin web: residentes, lotes, visitas, noticias, accesos
- Mobile: auth, home, visitas, scanner QR, noticias (lista + detalle), notificaciones, perfil
- Edge Functions: generate-qr, validate-qr, confirm-access (con re-verificación de token), manual-access
- Migración SQL: tabla notifications + RLS + trigger de noticias
- Badge de no leídas en el AppBar (realtime)

### 🔲 Pendiente para lanzar
- Aplicar migración `20260529_notifications.sql` en Supabase Dashboard
- Deployar edge functions: `supabase functions deploy confirm-access manual-access`
- Setear secret: `supabase secrets set QR_JWT_SECRET=<valor-seguro>`
- Deploy admin a Vercel
- Test end-to-end del flujo completo

## Convenciones de código

- Dart: camelCase para variables, PascalCase para clases
- TypeScript: camelCase para todo, interfaces con I-prefix solo si hay ambigüedad
- Commits: `feat:`, `fix:`, `docs:`, `refactor:`
- Siempre commitear al final de cada sesión de trabajo

## Variables de entorno necesarias

```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
QR_JWT_SECRET          ← setear en Supabase secrets
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
```
