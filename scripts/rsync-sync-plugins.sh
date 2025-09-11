#!/usr/bin/env bash
set -euo pipefail

# WYMAGANE zmienne środowiskowe (podawane w workflow):
#   SSH_USER, SSH_HOST, SSH_PORT (opcjonalnie, domyślnie 22), WP_ROOT
#   SSH_PRIVATE_KEY (jako secret), ew. RSYNC_EXTRA (opcjonalnie)

: "${SSH_USER:?Missing SSH_USER}"
: "${SSH_HOST:?Missing SSH_HOST}"
: "${WP_ROOT:?Missing WP_ROOT}"

SSH_PORT="${SSH_PORT:-22}"

echo "Apply protect filters:"
cat > /tmp/rsync-protect.filter <<'EOF'
# Chroń te wtyczki (nie nadpisuj/nie usuwaj po stronie serwera)
P litespeed-cache/**
P wordfence/**
P translatepress-multilingual/**
P cookie-law-info/**
EOF

echo "Protect filter file:"
wc -l /tmp/rsync-protect.filter
tail -n +1 /tmp/rsync-protect.filter

# Przygotuj klucz SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

export RSYNC_RSH="ssh -i ~/.ssh/id_rsa -p ${SSH_PORT} -o StrictHostKeyChecking=no"

# Katalog źródłowy w repo — dostosuj, jeśli u Ciebie inaczej
SRC_DIR="./plugins/"
DEST_DIR="${WP_ROOT%/}/wp-content/plugins/"

echo
echo "Sync: ${SRC_DIR} -> ${SSH_USER}@${SSH_HOST}:${DEST_DIR}"
echo

# UWAGA: --delete usuwa po stronie serwera wszystko, czego nie ma w SRC_DIR,
# ale reguły 'P' w pliku filtra chronią wskazane katalogi.
rsync -avz --delete \
  --filter="merge /tmp/rsync-protect.filter" \
  ${RSYNC_EXTRA:-} \
  "${SRC_DIR}" "${SSH_USER}@${SSH_HOST}:${DEST_DIR}"

echo
echo "Done."
