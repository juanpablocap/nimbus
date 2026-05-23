# Nimbus — Conventions

# General Principles

Consistency is more important than personal preference.

All code should prioritize:
- readability
- predictability
- simplicity
- maintainability

Avoid clever or overly abstract solutions.

---

# Official Language

## Internal Development Language

English only.

Used for:
- database tables
- columns
- code
- variables
- APIs
- commits
- documentation
- folders
- files

Examples:
- resident
- visit
- access_log
- incident

Do not mix English and Spanish.

---

# Naming Conventions

## Database

### Tables

Use:
- lowercase
- snake_case
- plural names

Examples:
- residents
- visits
- access_logs
- incidents

---

### Columns

Use:
- lowercase
- snake_case

Examples:
- community_id
- created_at
- updated_at

---

### Primary Keys

Always:
```sql
id UUID PRIMARY KEY
