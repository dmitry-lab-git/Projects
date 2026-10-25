# Ledger — История версионирования

> Источник истины: development.versions + development.version_updates • Автообновляется через dump.sh — 2026-10-25_14-24

## Эпохи (VER)

**VER-004 / V4 — Knowledge Kernel Architecture — 10.07.2026**
Переход к архитектуре Knowledge Kernel с PostgreSQL в роли вычислительного ядра, выделением независимого слоя для семантических связей и графов, а также развертыванием мобильного PWA-интерфейса.
Стек: PostgreSQL / PLpgSQL / Python / Reflex PWA / Graph Technologies | Устройство: Fujitsu U745

**VER-003 / V3 — PostgreSQL Ledger Structure — 13.06.2026**
Миграция в реляционную СУБД PostgreSQL и запуск системы надзора.
Стек: PostgreSQL / SQL (PL/pgSQL) | Устройство: Fujitsu U745

**VER-001 / V1 — Legacy Ledger Structure — 14.05.2026**
Первая форма учета: от бумажных журналов до локальных файлов.
Стек: Paper / Apple Numbers | Устройство: iPad 4

**VER-002 / V2 — Initial Ledger Structure — 14.05.2026**
Переход на неизменяемый регистр (Immutable Ledger) и архитектуру слоев.
Стек: Apple Numbers | Устройство: iPad 4


---

## Хроника изменений (UVR)

* **UVR-001 — 2026-05-15 — Legacy Ledger Structure**
  Реестр снимков баланса. Переход на ядро транзакций.
  Файлы: \LedgerExportFromiPad4\Raw Data\zip\csv: FLW-036, FLW-037

* **UVR-002 — 2026-06-13 — PostgreSQL Migration & ABS Setup**
  Переход из Numbers в PostgreSQL. ABS защита.
  Файлы: \LedgerExportFromiPad4\Raw Data\zip\csv: FLW-036, FLW-037, FLW-030

* **UVR-003 — 2026-06-13 — Ledger Calculation Logic Update**
  Приоритет математического знака операции. balance(i+1) = balance(i)+sum(i)*AccountEffect(TypeID);
  Файлы: function: refresh_ledger, function: refresh_account_state_report, table: account_state_report

* **UVR-004 — 2026-06-16 — ETL: Integration 1-446**
  Первичная загрузка среза 1-446 (Python/ETL).
  Файлы: FLW-030, etl_process.py, \FLW30 ETL 1-1728\Success stage1 ETL 1-446 16.06.26

* **UVR-005 — 2026-06-18 — ETL: Integration 447-1269**
  Загрузка и нормализация 447-1269 (Python/ETL).
  Файлы: FLW-030, etl_process.py, archive: \FLW30 ETL 1-1728\Success stage2 ETL 447-1269 18.06.26

* **UVR-006 — 2026-06-19 — Data Fusion: Full Merge**
  Полное объединение 1-1728. Финализация миграции. Данные верифицированы, соответствие 100%
  Файлы: db://public.table/tx_register

* **UVR-007 — 2026-06-19 — Ledger & Reporting Logic**
  Реализация ядра верифицированного финансового учета.
  Файлы: db://public.table/account_state_report, tx_register, ledger; db://public.func/refresh_ledger,refresh_account_state_report, archive: FLW30 ETL 1-1728\Final Common ETL

* **UVR-008 — 2026-06-20 — Infrastructure: DCS Service**
  Архитектурный план Data Collect Client Service.
  Файлы: \LedgerExportFromiPad4\Data Collect Client Service

* **UVR-009 — 2026-06-23 — ETL: Final Migration 1-1756**
  Завершение работы базового ETL-конвейера. Импорт исторических пакетов данных из Numbers через CSV.
  Файлы: files: FLW-036, FLW-037; script: etl_process.py

* **UVR-010 — 2026-06-25 — Core Reporting & Discrepancy Engine**
  Развертывание функций расчетов и автоматизированного контроля актов сверки баланса. Категоризация расхождений сальдо.
  Файлы: functions: public.refresh_ledger, public.refresh_account_state_report

* **UVR-011 — 2026-06-27 — Lightweight Analytics Layer**
  Разработка и запуск облегченной витрины данных для оперативного контроля исполнения конвейера функций и балансов.
  Файлы: view: reports.v_active_account_report

* **UVR-012 — 2026-06-29 — Core DDL Refactoring & Strict UUID Shift**
  Глобальный переход реестра транзакций на UUID-хранение. Ввод первых 5 транзакций.
  Файлы: table: public.transactions

* **UVR-013 — 2026-07-01 — Audit Architecture Deployment**
  Выделение обособленной схемы .audit для изоляции процессов верификации. Создание расширенного зеркала реестра.
  Файлы: schema: audit; table: audit.transactions_fullfields; indexes: idx_audit_status, idx_fullfields_code, idx_transactions_fullfields_keywords

* **UVR-014 — 2026-07-03 — AI Validation Engine (AIVE) Integration**
  Запуск интеллектуального конвейера на базе Gemini API. Внедрение прецедентного кэширования ai_notes.
  Файлы: script:aive_initial_audit.py, script:secure_api_call, table: aive_request_log

* **UVR-015 — 2026-07-04 — Multi-Stage AI Operational Auditing**
  Проведение 4-этапного автоматического аудита 1858 транзакций. Сбор статистики, фильтрация аномалий (trust_score < 8).
  Файлы: tables: audit.audit_process_queue, audit.staging_audit_results; function: audit.sync_transactions_to_fullfields

* **UVR-016 — 2026-07-06 — Interactive Manual Review Pipeline**
  Запуск консольного интерактивного скрипта для разбора 247 инцидентов оператором. Фиксация 57 точечных семантических правок.
  Файлы: script: manual_review.py; file: updates.txt; table: audit.staging_audit_results

* **UVR-017 — 2026-07-07 — Reflex PWA Interface Deployment**
  Развертывание интерфейса PWA на Reflex. Ввод snapshots. Интеграция форм ввода со словарями dicts, фиксация ввода первых 13 транзакций.
  Файлы: app: Reflex PWA; table: audit.staging_transactions; procedure: post_reviewed_transactions (deprecated)

* **UVR-018 — 2026-07-08 — Database Optimization & Clean State**
  Архитектурная зачистка структуры базы данных. Физическое удаление порядка 20 устаревших временных таблиц, сбор метаданных.
  Файлы: procedure: VACUUM ANALYZE; path: C:\Users\admin\Desktop\Ledger\db_dump_files

* **UVR-019 — 2026-07-08 — Git Initial Commit & Baseline Snapshot**
  Инициализация локального Git-репозитория и выполнение первого коммита. Фиксация базового контрольного состояния исходного кода, конфигурационных файлов и DDL-структуры СУБД.
  Файлы: repository: git init; commit: "Initial commit. Baseline snapshot of VER-003"

* **UVR-020 — 2026-07-10 — Development Environment Recovery Validation**
  Восстановление среды разработки на Windows 10 Pro из резервных копий PostgreSQL и архивов исходного кода, повторная инициализация Git. Утеря исходного снимка Git. Развертывание WSL и подтверждение полной воспроизводимости архитектуры VER-003.
  Файлы: Windows 10 Pro, PostgreSQL, Git Repository, WSL Linux, Project Sources, Database Dump

* **UVR-021 — 2026-07-10 — Knowledge Kernel Architecture Initialization**
  Инициализация архитектуры Knowledge Kernel. Начато проектирование изолированной схемы kernel для картирования объектов PostgreSQL, хранения семантических связей, Data Lineage и формирования графового слоя знаний без изменения транзакционного и вычислительного ядра системы.
  Файлы: schema: kernel; metadata graph; semantic relations; knowledge topology; architecture

* **UVR-022 — 2026-07-11 — WSL Database & Privilege Alignment**
  Настройка и миграция базы данных в окружение WSL, выдача необходимых прав доступа для схемы audit, схемы dicts и таблицы public.acc_balance_snapshot_register пользователю reflex_app_user. Проверка целостности и стабильности системы.
  Файлы: schema: audit; schema: dicts; table: public.acc_balance_snapshot_register; role: reflex_app_user

* **UVR-023 — 2026-07-11 — Ledger PWA Frontend & Navigation Refactor**
  Рефакторинг навигации PWA: создание Dashboard (главного меню), разделение функционала по роутам (/new-transaction, /snapshots, /active-accounts). Реализация умных выпадающих списков с JOIN-запросами, форматированием "Имя (Код)" и поиском. Интеграция автозаполнения даты/времени в форму транзакций.
  Файлы: routes: /, /new-transaction, /snapshots, /active-accounts; State: filtered filters & search_text; reports: v_active_account_report integration

* **UVR-024 — 2026-07-13 — Git Initial Commit**
  Git Initial Commit
  Файлы: \\wsl.localhost\Ubuntu\home\fujitsu-u745\Projects

* **UVR-025 — 2026-09-28 — Ledger Return Inversion Logic Validation**
  Фиксация архитектурного принципа инверсии математического знака для отражения возвратов денежных средств. Отказ от расширения словаря типов операций в пользу сохранения преемственности аналитик (категория/проект). Подтверждена совместимость с вычислительным ядром balance(i+1) = balance(i) + sum(i) * AccountEffect(TypeID) и расчетом брутто-оборотов через ABS(sum).
  Файлы: table: public.transactions, function: public.refresh_ledger

* **UVR-026 — 2026-10-01 — Contragent Precedents Data Architecture**
  Проектирование и развертывание подсистемы учета прецедентов контрагентов. Интеграция с глобальным справочником dicts.dict_statuses. Реализовано разделение архитектуры на информативную ветвь (исторический скоринг надежности) и делопроизводственную ветвь (активное управление правовыми и претензионными спорами). Внесены первые три прецедента с уникальными UUID.
  Файлы: table: public.contragent_precedents, table: dicts.dict_statuses, active_cases: b2b9ffd8 (Швейный дом), 4cd26864 (12 месяцев), a4cae3a4 (Арбузы)

* **UVR-027 — 2026-10-01 — Secure Automated Infrastructure Triumvirate**
  Развертывание защищенного автоматизированного контура резервного копирования внутри WSL Linux с выгрузкой на физический диск Windows и облачной репликацией в Google Drive. Изоляция учетных данных СУБД во внешней папке secure_folder в формате Unix-строк (LF). Настройка еженедельного циклического планировщика cron для параллельного создания снимков баз ledger, household и упаковки всего корневого Git-репозитория посредством git bundle.
  Файлы: service: linux-cron, script: make_dump.sh, script: make_dump_household.sh, script: make_dump_git.sh, config: Projects/secure_folder/postgre_sql/credentials.conf, archive_target: projects_root_*.bundle

* **UVR-028 — 2026-10-02 — Medicine PWA Module Isolation & Schema Integration**
  Разработка и внедрение изолированного доменного модуля «Medicine PWA» для учета БАДов, регистрации приемов препаратов и ведения дневника физиологических наблюдений. Создана схема БД medicine с ORM-моделями (SupplementCatalog, SupplementIntake, ObservationLog). Реализовано состояние MedicineState с динамической загрузкой данных, сессионным управлением БД и автосбросом полей. Разработаны интерфейсные компоненты, роутинг с переключением даты/времени и точка входа на главной странице приложения.
  Файлы: schema: medicine; models: SupplementCatalog, SupplementIntake, ObservationLog; state: MedicineState; file: pwa/ui/components/medicine_form.py; page: pwa/ui/pages/medicine.py; entrypoint: pwa/ui/pages/index.py

* **UVR-029 — 2026-10-02 — Dictionaries PWA Management Module Integration**
  Интегрирован модуль управления справочниками схемы dicts (Address, Contragent, Merchant) основной базы данных ledger. Реализованы ORM-модели, состояние DictionariesState с привязкой к движку БД engine, интерфейсные формы и таблицы управления. Настроены дефолтные значения географии (Павлодар, Казахстан), выбор типов контрагентов («Физическое лицо», «Юридическое лицо») и кнопка быстрого перехода на главной странице.
  Файлы: schema: dicts; models: Address, Contragent, Merchant; state: DictionariesState; file: pwa/ui/components/dictionaries_form.py; page: pwa/ui/pages/dictionaries.py; entrypoint: pwa/ui/pages/index.py

* **UVR-030 — 2026-10-09 — Cross-Database Project Registry**
  Реализован кросс-базовый учет проектов между ledger и household. Добавлены редактор проектов, управление статусами и JSONB-метаданными, смарт-поиск и просмотр параметров.
  Файлы: databases: ledger, household; tables: projects.registry, projects.metadata, dicts.dict_statuses; route: /projects/editor; files: pwa/state/projects.py, pwa/ui/components/projects.py, pwa/ui/pages/projects.py, pwa/ui/pages/project_editor.py, pwa/registry/updates.md

* **UVR-031 — 2026-10-09 — Reflex Development Architecture Prompt**
  Обновлён системный промпт разработки Reflex-модулей. Зафиксированы архитектурное разделение слоёв, правила кросс-базового In-Memory Join, работа с JSONB, типизация состояния, обработка ошибок, права PostgreSQL, тестирование и Git-контроль изменений.
  Файлы: file: prompts/pwa_page_creating.txt; stack: Reflex, Python, SQLAlchemy, PostgreSQL; databases: ledger, household

* **UVR-032 — 2026-10-10 — Reusable Development Model & Architecture Shift**
  Зафиксирован переход к самостоятельной разработке на основе повторно используемых архитектурных решений, модулей и стандартизированных промптов. Реализация Cross-Database Project Registry приблизительно за 2–3 часа подтвердила возможность быстрого создания функциональных модулей. Работа над проектом стала субъективно ощущаться легче: снизилось когнитивное и организационное сопротивление, разработка стала восприниматься как более естественный и управляемый процесс. Это рассматривается как важный фактор устойчивости и масштабирования проекта.
  Файлы: UVR-030, UVR-031, prompts/pwa_page_creating.txt, Reflex, Python, SQLAlchemy, PostgreSQL

* **UVR-033 — 2026-10-15 — Power Failure Incident & Backup Automation**
  Успешное разрешение нештатной ситуации (инцидент со скачком напряжения в электросети, перебоем питания и последующим жестким зависанием ПК Fujitsu U745 с темным экраном). Проведена проверка системных логов Windows (Kernel-Power) и журналов PostgreSQL, подтвердившая автоматическое восстановление целостности данных СУБД. В качестве превентивной меры разработана отказоустойчивая система из 5 раздельных процессов: создание дампов БД (ledger, household) и бандлов Git, а также изолированные сервисные модули долгосрочной архивации понедельников (/Archive) и автоматической очистки скользящего недельного окна. Управление расписанием вынесено в schedule.conf, настроены интерактивные уведомления Wscript.Shell и bat-файл для Windows.
  Файлы: crontab, file: schedule.conf, script: update_schedule.sh, script: run_all_now.sh, script: archive_untouchable.sh, script: clean_and_rotate.sh, script: make_dump.sh, script: make_dump_household.sh, script: make_dump_git.sh, file: Run_All_Backups_Now.bat, path: /home/fujitsu-u745/Projects/Ledger/archiving_process

* **UVR-034 — 2026-10-16 — Fault Tolerance & Archive Alignment**
  Развертывание контура отказоустойчивости (Fault Tolerance) для защиты архивных данных от преждевременного удаления. Внедрен механизм квитирования: скрипт archive_untouchable.sh генерирует флаг успешного переноса archive_success.flag, а модуль clean_and_rotate.sh блокирует очистку и выдает критическое уведомление в Windows при отсутствии квитанции в контрольные дни (Mon/Tue). Произведено ручное структурирование репозитория бэкапов: все исторические дампы и бандлы перемещены в изолированную директорию /Archive, сформировав эталонную точку отсчета для долгосрочного хранения с синхронизацией в Google Drive.
  Файлы: script: archive_untouchable.sh, script: clean_and_rotate.sh, path: C:\Personal\Projects\Archive\db_dump_files\Archive, file: archive_success.flag

* **UVR-035 — 2026-10-22 — Staging Table Architecture**
  Creation of the intermediate staging table audit.staging_transactions_v1_1 designed to modernize the transaction data architecture, implement UUID-based status mapping, and establish a baseline audit against public.transactions.
  Файлы: schema: audit, table: audit.staging_transactions_v1_1, table: public.transactions

* **UVR-036 — 2026-10-22 — ETL Migration and Reconciliation Analysis**
  Execution of ETL for 277 records into audit.staging_transactions_v1_1. Comprehensive 18-field reconciliation against public.transactions revealed localized discrepancies across attributes, explicitly confirming that data divergence is driven by post-publication manual corrections and overrides applied in the primary register.
  Файлы: table: audit.staging_transactions_v1_1, table: public.transactions, table: dicts.dict_statuses

* **UVR-037 — 2026-10-22 — Transaction Status Normalization**
  Migration of public.transactions from string-based status to normalized UUID status_id referencing dicts.dict_statuses. Implemented explicit mapping (reviewed -> POSTED, IMPORTED -> IMPORTED), established NOT NULL constraints, foreign key relation, and dropped the legacy status column.
  Файлы: table: public.transactions, table: dicts.dict_statuses

* **UVR-038 — 2026-10-22 — Staging Promotion & Adaptation**
  Archive rotation of the old staging table to backup, promotion of audit.staging_transactions_v1_1 to the production table audit.staging_transactions. Adaptation and successful compilation of the audit.post_reviewed_transactions() function for the strict normalized UUID status architecture from dicts.dict_statuses.
  Файлы: table: audit.staging_transactions, table: audit.staging_transactions_v1_1, function: audit.post_reviewed_transactions, table: dicts.dict_statuses

* **UVR-039 — 2026-10-23 — PWA Adaptation & Templates UUID Migration**
  Адаптация Reflex PWA интерфейса под архитектурные изменения. Реализована возможность внесения данных в staging_transactions через интерфейс, а также внедрена поддержка шаблонов транзакций (transaction_templates) с полным переводом на UUID-архитектуру и привязкой к словарям.
  Файлы: app: Reflex PWA, table: processing.transaction_templates, table: audit.staging_transactions


---
_Last sync: 2026-10-25_14-24 — 4 versions, 39 updates_
