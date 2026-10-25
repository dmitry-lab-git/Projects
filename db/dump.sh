#!/bin/bash
set -e
BASE=~/Projects/db
DATE=$(date +%Y-%m-%d_%H-%M)

for DB in ledger household; do
  DIR=$BASE/$DB
  mkdir -p $DIR/tables $DIR/views $DIR/functions
  echo "[$DATE] Dumping $DB..."

  # ПОЛНАЯ ОЧИСТКА старых дампов
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

cd ~/Projects
git add db/
git status --short | head -50
if ! git diff --cached --quiet -- db/; then
  git commit -m "auto: db dump $DATE clean" -- db/
  git push
else
  echo "No changes"
fi
