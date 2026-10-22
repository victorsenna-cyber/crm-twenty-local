#!/bin/sh
# Para o CRM com o banco fechado direito. Com $1 (pasta do Windows), salva antes uma cópia do banco nela.
. /opt/twenty/config.env 2>/dev/null   # PG_PORTA e REDIS_PORTA: nunca mexer no Postgres/Redis de outra distro
PG_PORTA=${PG_PORTA:-5442}; REDIS_PORTA=${REDIS_PORTA:-6389}
D=/data
if [ -n "$1" ] && pg_isready -h 127.0.0.1 -p $PG_PORTA -q; then
  BK=$(wslpath -u "$1")
  mkdir -p "$BK"
  pg_dump -U postgres -h 127.0.0.1 -p $PG_PORTA -Fc default > "$BK/crm-$(date +%Y-%m-%d_%H%M).dump" && \
    ls -1t "$BK"/crm-*.dump | tail -n +15 | while read -r f; do rm -f "$f"; done   # guarda as 14 mais recentes
fi
pkill -f 'dist/main' 2>/dev/null
pkill -f 'queue-worker' 2>/dev/null
redis-cli -h 127.0.0.1 -p $REDIS_PORTA shutdown nosave > /dev/null 2>&1
su-exec postgres pg_ctl -D $D/postgres -m fast -w stop > /dev/null 2>&1
true
