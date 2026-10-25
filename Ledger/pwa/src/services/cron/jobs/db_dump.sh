#!/bin/bash
set -e
BASE=~/Projects/db
DATE=$(date +%Y-%m-%d_%H-%M)

for DB in ledger household; do
  DIR=$BASE/$DB
  mkdir -p $DIR/tables $DIR/views $DIR/functions
  echo "[$DATE] Dumping $DB..."

  rm -f $DIR/tables/*.sql $DIR/views/*.sql $DIR/functions/*.sql

  FILTER="AND tablename NOT LIKE 'archive_%' AND tablename NOT LIKE '%_backup%'"
  sudo -u postgres pg_dump -d $DB --schema-only --no-owner > $DIR/full_schema.sql

  sudo -u postgres psql -d $DB -t -c "SELECT schemaname||'.'||tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') $FILTER" | while read T; do
    T=$(echo $T | xargs); [ -z "$T" ] && continue
    FILE=$(echo $T | tr '.' '_' | tr -d '\r').sql
    sudo -u postgres pg_dump -d $DB --schema-only --no-owner -t "$T" > "$DIR/tables/$FILE" 2>/dev/null || true
  done

  sudo -u postgres psql -d $DB -t -c "SELECT schemaname||'.'||viewname FROM pg_views WHERE schemaname NOT IN ('pg_catalog','information_schema')" | while read V; do
    V=$(echo $V | xargs); [ -z "$V" ] && continue
    FILE=$(echo $V | tr '.' '_' | tr -d '\r').sql
    sudo -u postgres pg_dump -d $DB --schema-only --no-owner -t "$V" > "$DIR/views/$FILE" 2>/dev/null || true
  done

  echo "Dumping functions (only user)..."
  sudo -u postgres psql -d $DB -At -F '|' -c "
    SELECT p.oid, n.nspname, p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname NOT IN ('pg_catalog','information_schema')
      AND p.prokind IN ('f','p')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid=p.oid AND d.deptype='e')
      AND n.nspname IN ('public','audit','reports','processing','dicts','kernel','development')
  " | while IFS='|' read OID SCHEMA NAME; do
    OID=$(echo $OID | xargs); SCHEMA=$(echo $SCHEMA | xargs); NAME=$(echo $NAME | xargs)
    [ -z "$OID" ] && continue
    FILE="${SCHEMA}_${NAME}.sql"
    sudo -u postgres psql -d $DB -At -c "SELECT pg_get_functiondef($OID)" > "$DIR/functions/$FILE" 2>/dev/null || true
  done
  echo " -> tables:$(ls $DIR/tables|wc -l) views:$(ls $DIR/views|wc -l) functions:$(ls $DIR/functions|wc -l)"
done

# === VERSIONING BEAUTIFUL ===
VER_FILE=~/Projects/Ledger/VERSIONING.md
mkdir -p ~/Projects/Ledger
echo "# Ledger — История версионирования" > "$VER_FILE"
echo "" >> "$VER_FILE"
echo "> Источник истины: development.versions + development.version_updates • Автообновляется через dump.sh — $DATE" >> "$VER_FILE"
echo "" >> "$VER_FILE"
echo "## Эпохи (VER)" >> "$VER_FILE"
echo "" >> "$VER_FILE"
sudo -u postgres psql -d ledger -At -c "
SELECT '**' || version_id || ' / ' || version_code || ' — ' || version_name || ' — ' || registration_date || '**' || E'\n' || description || E'\n' || 'Стек: ' || programming_stack || ' | Устройство: ' || dev_device || E'\n'
FROM development.versions ORDER BY registration_date
" >> "$VER_FILE"
echo "" >> "$VER_FILE"
echo "---" >> "$VER_FILE"
echo "" >> "$VER_FILE"
echo "## Хроника изменений (UVR)" >> "$VER_FILE"
echo "" >> "$VER_FILE"
sudo -u postgres psql -d ledger -At -c "
SELECT '* **' || update_version_id || ' — ' || registration_date || ' — ' || update_version_name || '**' || E'\n  ' || description || E'\n  Файлы: ' || COALESCE(affected_objects,'') || E'\n'
FROM development.version_updates ORDER BY registration_date, code
" >> "$VER_FILE"
echo "" >> "$VER_FILE"
echo "---" >> "$VER_FILE"
VC=$(sudo -u postgres psql -d ledger -At -c "SELECT count(*) FROM development.versions")
UC=$(sudo -u postgres psql -d ledger -At -c "SELECT count(*) FROM development.version_updates")
echo "_Last sync: $DATE — $VC versions, $UC updates_" >> "$VER_FILE"
echo " -> VERSIONING: $(wc -l < "$VER_FILE") lines"

cd ~/Projects
git add db/ Ledger/VERSIONING.md
git status --short | head -50
if ! git diff --cached --quiet -- db/ Ledger/VERSIONING.md; then
  git commit -m "auto: db dump $DATE clean + versioning" -- db/ Ledger/VERSIONING.md
  git push
else
  echo "No changes"
fi