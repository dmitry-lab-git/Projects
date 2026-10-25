# Project: Ledger PWA
## Overview
A web-based ledger and transaction management application built with **Reflex**.
- **Frontend/Backend:** Python-based full-stack framework (Reflex).
- **Database:** PostgreSQL managed via SQLAlchemy.

## Getting Started
### Prerequisites
- Python 3.10+
- PostgreSQL
- Reflex installed (`pip install reflex`)

### Configuration
1. Update `.env` with your `DATABASE_URL`.
   *Note: Ensure the path to `.env` is correctly referenced in `pwa/db.py` (currently hardcoded as `C:\Users\admin\Desktop\Ledger\secure_folder\pwa\.env`).*

## Key Project Structure
- `pwa/pwa.py`: Main state management and UI components.
- `pwa/db.py`: Database connection and session management.
- `pwa/models.py`: SQLAlchemy table definitions.

## Database Note
The transaction tables have been migrated to the `audit` schema.
- **Old Location:** `development.staging_transactions`
- **New Location:** `audit.staging_transactions`
Ensure your DB user has `USAGE` on `audit` schema and `SELECT` rights on tables within it.

## Common Tasks
- **Updating Queries:** When adding new queries, use the `audit` schema prefix.
- **Running App:** `reflex run`
