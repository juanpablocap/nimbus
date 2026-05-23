# Nimbus — Roadmap

# Product Strategy

Nimbus will be built incrementally.

The priority is:
- operational simplicity
- reliability
- fast iteration
- real-world validation

The MVP must remain intentionally small.

Avoid building future features before validating the core operational flows.

---

# Development Priorities

The order of priorities is:

1. architecture
2. database
3. authentication
4. permissions
5. core operational flows
6. UI polish
7. secondary features

Infrastructure and complexity should evolve only when necessary.

---

# Phase 1 — Foundation

## Goal

Build the technical foundation of the platform.

---

## Tasks

### Repository Setup
- monorepo structure
- pnpm workspaces
- GitHub repository
- environment configuration

### Documentation
- architecture
- conventions
- roadmap
- permissions
- database design

### Backend Foundation
- Supabase project
- authentication
- PostgreSQL schema
- RLS policies
- storage structure

### Design Foundation
- typography
- spacing system
- colors
- component philosophy
- dark mode support

---

# Phase 2 — MVP Core

## Goal

Build the minimum operational product.

---

# Resident Features

## Authentication
- login
- magic link
- OTP support

## Profile
- resident profile
- property association

## Visits
- create visit
- temporary access
- expiration rules
- QR generation

## News
- community feed
- announcements

---

# Guard Features

## QR Validation
- scan QR
- validate access
- approve/reject entry

## Access Logs
- view recent entries
- search active visits

---

# Admin Features

## Dashboard
- operational overview
- active visits
- incidents summary

## Resident Management
- residents
- properties
- assignments

## News Management
- publish announcements
- manage visibility

---

# Phase 3 — Operational Expansion

## Goal

Improve operational capabilities.

---

## Features

### Incidents
- incident reporting
- image uploads
- assignments
- status tracking

### Notifications
- push notifications
- realtime alerts

### Vehicle Management
- vehicle registration
- plate validation

### Employees
- domestic workers
- recurring permissions

### Analytics
- access metrics
- operational statistics

---

# Phase 4 — Community Platform

## Goal

Expand Nimbus into a full community platform.

---

## Features

### Amenities
- reservations
- schedules

### Payments
- expenses
- invoices
- payment tracking

### Marketplace
- internal services
- classifieds

### Community Tools
- surveys
- polls
- events

---

# Phase 5 — Smart Infrastructure

## Goal

Long-term infrastructure integrations.

---

## Features

### Smart Access
- IoT integrations
- smart gates

### CCTV
- camera integrations
- event linking

### AI Monitoring
- anomaly detection
- operational alerts

### Energy Management
- EV infrastructure
- solar integrations
- smart consumption

---

# MVP Definition

The MVP includes ONLY:

## Residents
- authentication
- profile
- create visit
- QR access
- news feed

## Guards
- QR validation
- access approval
- access logs

## Admins
- residents management
- properties management
- news management

Everything else is excluded from the MVP.

---

# What We Intentionally Delay

The following are intentionally postponed:
- payments
- reservations
- AI features
- camera integrations
- complex analytics
- automation systems
- external ERP integrations

These features increase complexity significantly.

---

# Success Criteria for MVP

The MVP succeeds if:
- residents can create visits easily
- guards can validate access quickly
- admins can manage residents efficiently
- the system feels fast and reliable

Operational simplicity is more important than feature quantity.

---

# Product Philosophy

Nimbus should evolve carefully.

Every new feature must justify:
- operational value
- user clarity
- maintenance cost
- scalability impact

Avoid feature bloat.

A smaller and cleaner platform is preferable to a bloated system.
