<!-- LEDGER_METRICS_START -->
## 📊 Ledger SystemMetrics (auto-updated: 25.10.2026 20:14:24)

| Metric | Value | Description |
|--------|-------|-------------|
| **Current transaction count** | **2136** | `public.transactions` |
| **Account reconciliation statements** | **146** | `public.acc_balance_snapshot_register` |
| **Verified states** | **6** | `reports.system_verification_log` since 13.10.2026 |
| **PWA Staging stream** | **278** | `audit.staging_transactions` |

> Balance formula: `balance(i+1) = balance(i) + sum(i) * AccountEffect(TypeID)`

_Updated daily at 00:00 (Pavlodar, Astana) via APScheduler (Reflex PWA backend)_
<!-- LEDGER_METRICS_END -->

---

---

---

---

The central domain module of the monorepo, providing verified financial accounting, automated transaction postings, balance reconciliation, and analytical reporting.

---

## 📑 Architecture & Key Evolution Milestones (UVR)

The evolution of the Ledger subsystem is tracked in a comprehensive unified version record (UVR):

### Phase 1: Core Foundation & Data Migration (VER-002 -> VER-003)
* **Shift to Transaction Model (UVR-001):** Migrated from legacy manual tracking of asset balance snapshots to a centralized transaction-based registry. Historical data was successfully imported via CSV files (`FLW-036`, `FLW-037`).
* **PostgreSQL Migration (UVR-002, UVR-004, UVR-005, UVR-009):** Implemented a structured relational database layout in PostgreSQL. Developed a multi-stage Python ETL pipeline (`etl_process.py`) to normalize and import 1,756 historical records.
* **Operational Accounting Logic (UVR-003, UVR-025):** Established a strict priority for the mathematical signs of operations. Balance computation follows the core formula:  
  `balance(i+1) = balance(i) + sum(i) * AccountEffect(TypeID)`.  
  Validated return inversion logic to mirror refunds using existing transaction analytics without expanding the operation types dictionary.
* **Computational Layer (UVR-006, UVR-007, UVR-010):** Finalized full data fusion with 100% verification matching. Deployed primary procedures `public.refresh_ledger()` and `public.refresh_account_state_report()`.

### Phase 2: Analytics, Auditing & AI-Validation (VER-003)
* **Lightweight Analytics (UVR-011):** Launched an operational data mart via the database view `reports.v_active_account_report`.
* **Strict UUID Migration (UVR-012):** Executed a global DDL refactoring to shift the transaction registry (`public.transactions`) to secure UUID storage.
* **Isolated Audit Layout (UVR-013, UVR-015, UVR-016):** Dedicated a distinct `.audit` schema to isolate verification processes. Ran a multi-stage automated audit pipeline for 1,858 records, filtering anomalies based on trust metrics (`trust_score < 8`). Discrepancies were resolved via an interactive manual script (`manual_review.py`), securing 57 semantic corrections.
* **AI Validation Engine Integration (UVR-014):** Connected an intelligent pipeline powered by the Gemini API (`aive_initial_audit.py`) with precedent-based caching of expert insights (`ai_notes`) in `aive_request_log`.

### Phase 3: WSL, Reflex PWA & Infrastructure Shifting (VER-004)
* **WSL Migration & Privilege Alignment (UVR-020, UVR-022):** Shifted the environment and database completely to Linux WSL. Restructured access privileges across `audit`, `dicts`, and core tables to match the `reflex_app_user` service role.
* **Reflex PWA Interface (UVR-017, UVR-023, UVR-039):** Deployed a cross-platform Web Application interface using the Reflex Python framework. Built a centralized Dashboard alongside custom routes for transactions input, snapshots, and account monitoring. Integrated smart dropdown lookup fields using PostgreSQL JOIN statements.
* **Domain Model Expansion (UVR-026, UVR-028, UVR-029, UVR-030):** 
    * Deployed a legal precedents tracking subsystem (`public.contragent_precedents`) for contractor reliability scoring and claims management.
    * Integrated an isolated domain module `Medicine PWA` (schema `medicine`) to record physiological data, supplements, and intakes.
    * Engineered a cross-database project registry (`projects.registry`) utilizing JSONB metadata to link `ledger` and `household` projects.

### Phase 4: Strict Normalization & Fault Tolerance (Current State)
* **Automated Backup "Triumvirate" (UVR-027, UVR-033):** Configured a resilient backup environment via Linux `cron` executing 5 distinct automated processes (parallel logical dumps of `ledger` and `household`, along with full repository archiving via `git bundle`). Protected credentials via Unix-terminated lines (LF) in an isolated `secure_folder`.
* **Fault Tolerance & Archive Guard (UVR-034):** Deployed an archive handshake mechanism. The `archive_untouchable.sh` script produces a confirmation flag `archive_success.flag` upon a successful remote cloud upload. If missing on checkpoint days, rotation routines are locked, triggering high-priority alerts.
* **Transaction Status UUID Normalization (UVR-035, UVR-036, UVR-037, UVR-038):** Fully migrated the primary transaction register from string-based statuses to a strict foreign key constraint referencing `dicts.dict_statuses`. Adapted and recompiled the core pipeline function `audit.post_reviewed_transactions()` to match. Shifted transaction templates (`processing.transaction_templates`) to the same normalized structure.

---

## 📂 Subsystem Directory Layout

The codebase for the Ledger engine is organized across the following layers of the monorepo:

* **`Ledger/`** — Contains backend core business logic, migration assets, data processing modules, and the Reflex PWA codebase (page `State` definitions, form components, and responsive views).
* **`db/ledger/`** — Acts as the single source of truth for the PostgreSQL database structure:
    * `tables/` — Contains declarative DDL tracking scripts (`public.transactions`, `processing.transaction_templates`, `audit.staging_transactions`, etc.).
    * `views/` — Database representations and optimized light-weight analytics data marts.
    * `functions/` — Core database mathematical tier composed of 35 stored procedures and operational database triggers.
* **`infra/`** — Houses system environment definitions, `systemd` unit services, `nginx` reverse-proxy layouts, and a dedicated `wsl/` directory specifying automation shell scripts, rotation processes, and `cron` schedules.

---

## 🛠️ Technological Stack

* **Database Engine:** PostgreSQL (Version 18.6 running on Ubuntu / WSL Linux)
* **Development Language:** Python (SQLAlchemy ORM integration)
* **Frontend UI Framework:** Reflex (PWA web layer architecture)
* **Integrations:** Gemini API (Automated Intelligent Validation Engine — AIVE)
* **Infrastructure Layer:** Bash, Linux CLI, WSL environment, Cron, Git Bundle

