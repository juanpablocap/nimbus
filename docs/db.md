# Nimbus — Database Design

# Philosophy

Nimbus uses PostgreSQL as the single source of truth.

The database is designed around:
- multi-tenant architecture
- security
- auditability
- scalability
- operational simplicity

All critical business logic should be supported by a strong relational model.

---

# Core Principles

## Multi-Tenant First

Every tenant-aware table MUST include:

```sql id="xghzpx"
community_id UUID NOT NULL
