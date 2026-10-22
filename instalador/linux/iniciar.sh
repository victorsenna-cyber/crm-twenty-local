#!/bin/sh
# Sobe o CRM inteiro dentro da distro WSL: PostgreSQL, Redis, migrações, worker e servidor.
# Fica em primeiro plano (o servidor) para a distro não desligar enquanto o app estiver aberto.
set -e
. /opt/twenty/config.env          # PORTA, PG_PORTA e REDIS_PORTA, escritas pelo instalador
# portas próprias: as distros WSL dividem a rede, e 5432/6379 podem ser de outro Postgres/Redis da máquina
PG_PORTA=${PG_PORTA:-5442}; REDIS_PORTA=${REDIS_PORTA:-6389}
D=/data
mkdir -p $D/postgres $D/redis $D/storage $D/logs /run/postgresql
touch $D/logs/postgres.log
chown postgres:postgres $D/postgres /run/postgresql $D/logs/postgres.log

# segredos: gerados uma vez por máquina, ficam só aqui dentro
if [ ! -s /opt/twenty/segredos.env ]; then
  printf 'ENCRYPTION_KEY=%s\nAPP_SECRET=%s\n' "$(head -c 32 /dev/urandom | base64)" "$(head -c 32 /dev/urandom | base64)" > /opt/twenty/segredos.env
  chmod 600 /opt/twenty/segredos.env
fi
set -a; . /opt/twenty/segredos.env; set +a

export NODE_ENV=production NODE_PORT=$PORTA SERVER_URL=http://localhost:$PORTA \
  PG_DATABASE_URL=postgres://twenty:twenty@127.0.0.1:$PG_PORTA/default \
  REDIS_URL=redis://127.0.0.1:$REDIS_PORTA \
  STORAGE_TYPE=local STORAGE_LOCAL_PATH=$D/storage \
  IS_BILLING_ENABLED=false

if [ ! -s $D/postgres/PG_VERSION ]; then
  su-exec postgres initdb -D $D/postgres -U postgres --auth=trust -E UTF8 --locale=C.UTF-8 > $D/logs/initdb.log
fi
su-exec postgres pg_ctl -D $D/postgres -l $D/logs/postgres.log -o "-c listen_addresses=127.0.0.1 -c port=$PG_PORTA" -w start > /dev/null || true
psql -U postgres -h 127.0.0.1 -p $PG_PORTA -tAc "SELECT 1 FROM pg_roles WHERE rolname='twenty'" | grep -q 1 \
  || psql -U postgres -h 127.0.0.1 -p $PG_PORTA -qc "CREATE ROLE twenty LOGIN SUPERUSER PASSWORD 'twenty'"
psql -U postgres -h 127.0.0.1 -p $PG_PORTA -tAc "SELECT 1 FROM pg_database WHERE datname='default'" | grep -q 1 \
  || psql -U postgres -h 127.0.0.1 -p $PG_PORTA -qc 'CREATE DATABASE "default" OWNER twenty'

redis-cli -h 127.0.0.1 -p $REDIS_PORTA ping > /dev/null 2>&1 || \
  redis-server --daemonize yes --bind 127.0.0.1 --port $REDIS_PORTA --dir $D/redis --maxmemory-policy noeviction --logfile $D/logs/redis.log

cd /app/packages/twenty-server
sh /app/entrypoint.sh true > $D/logs/migracao.log 2>&1   # migrações: o entrypoint oficial da imagem
node dist/queue-worker/queue-worker > $D/logs/worker.log 2>&1 &
exec node dist/main > $D/logs/servidor.log 2>&1
