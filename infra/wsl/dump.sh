#!/bin/bash
set -e
BASE=~/Projects/db
DATE=$(date +%Y-%m-%d_%H-%M)

for DB in ledger household; do
  DIR=$BASE/$DB
  mkdir -p $DIR/tables $DIR/views

  echo "[$DATE] Dumping $DB..."

  # Игнорим архивные таблицы
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
done

# Коммитим только db/
cd ~/Projects
git add db/
if ! git diff --cached --quiet -- db/; then
  git commit -m "auto: db dump $DATE" -- db/
  git push
else
  echo "No changes in db/"
fi