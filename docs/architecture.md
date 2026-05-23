# Nimbus — Architecture

# Overview

Nimbus is a cloud-native multi-tenant SaaS platform designed for private communities and gated neighborhoods.

The system architecture prioritizes:
- simplicity
- scalability
- security
- maintainability
- realtime responsiveness

Nimbus is designed to support multiple communities from a single infrastructure without requiring isolated deployments.

---

# High-Level Architecture

```txt
Mobile App (Flutter)
        |
        | HTTPS / Realtime
        v
Supabase Backend
├── PostgreSQL
├── Authentication
├── Realtime
├── Storage
├── Edge Functions
└── Row Level Security
        |
        v
Admin Dashboard (Next.js)
