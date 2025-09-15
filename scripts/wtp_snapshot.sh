#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${RUN_ID:?RUN_ID is required}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
mkdir -p "${LOGDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

note_err() { echo "$1" | tee -a "${ERR_FILE}" 1>&2 || true; }
run_wp()   { php ./wp "$@" --path="${TARGET}"; }

# --- jq availability ---
JQ_OK=1
if ! command -v jq >/dev/null 2>&1; then
  JQ_OK=0
  note_err "jq not found – JSON aggregation will use minimal fallback."
fi

# ---------- A) Site/Core ----------
SITE_URL="$(run_wp option get siteurl 2>/dev/null || true)"
SITE_HOME="$(run_wp option get home 2>/dev/null || true)"
WP_VER="$(run_wp core version 2>/dev/null || true)"
TABLE_PREFIX="$(grep -E "^\s*\\\$table_prefix\s*=" "${TARGET}/wp-config.php" 2>/dev/null \
  | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | head -n1 || echo "wp_")"
WPLANG="$(run_wp option get WPLANG 2>/dev/null || true)"
TZ_STR="$(run_wp option get timezone_string 2>/dev/null || run_wp option get gmt_offset 2>/dev/null || true)"
PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
php -v > "${LOGDIR}/php_info.txt" || true

if [[ "${JQ_OK}" -eq 1 ]]; then
  jq -n \
    --arg url "${SITE_URL}" \
    --arg home "${SITE_HOME}" \
    --arg wp_version "${WP_VER}" \
    --arg table_prefix "${TABLE_PREFIX}" \
    --arg language "${WPLANG}" \
    --arg timezone "${TZ_STR}" \
    --arg php_version "${PHP_VERSION}" \
    '{url:$url,home:$home,wp_version:$wp_version,table_prefix:$table_prefix,language:$language,timezone:$timezone,php_version:$php_version}' \
    > "${LOGDIR}/site_info.json"
fi

# ---------- B) Themes ----------
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" || true
run_wp theme list --format=json > "${LOGDIR}/themes.json" || true

# ---------- C) Plugins (standard) ----------
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" || true
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" || true

# Extra: per-plugin tree + hashes
PLUGINS_DIR="${TARGET}/wp-content/plugins"
PLUG_TREE_SUMMARY="${LOGDIR}/plugins_trees.json"
echo '{}' > "$PLUG_TREE_SUMMARY"
if [[ -d "$PLUGINS_DIR" && "${JQ_OK}" -eq 1 ]]; then
  while read -r slug; do
    OUTDIR="${LOGDIR}/plugins/${slug}"
    mkdir -p "$OUTDIR"
    find "$PLUGINS_DIR/$slug" -type f | sort > "$OUTDIR/tree.txt" || true
    sha1sum $(find "$PLUGINS_DIR/$slug" -type f) > "$OUTDIR/hashes.sha1" || true
    FILES_COUNT=$(wc -l < "$OUTDIR/tree.txt" || echo 0)
    SHA_ALL=$(sha1sum $(find "$PLUGINS_DIR/$slug" -type f) 2>/dev/null | sha1sum | awk '{print $1}' || echo "")
    TMP=$(mktemp)
    jq --arg slug "$slug" --argjson files "$FILES_COUNT" --arg sha1 "$SHA_ALL" \
       '. + {($slug):{files:$files,sha1:$sha1}}' "$PLUG_TREE_SUMMARY" > "$TMP" && mv "$TMP" "$PLUG_TREE_SUMMARY"
  done < <(jq -r '.[].name' "${LOGDIR}/plugins.json" 2>/dev/null || true)
fi

# ---------- D) MU-plugins ----------
MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"
if [[ -d "${MU_DIR}" ]]; then
  ls -la "$MU_DIR" > "${LOGDIR}/mu-plugins/_ls.txt" || true
  find "$MU_DIR" -type f -exec sha1sum {} \; > "${LOGDIR}/mu-plugins/_hashes.txt" || true
  for f in "$MU_DIR"/*.php; do
    [[ -f "$f" ]] || continue
    head -n 50 "$f" | grep -E "^\s*\*\s*Plugin Name:" > "${LOGDIR}/mu-plugins/$(basename "$f").header.txt" || true
  done
else
  echo "mu-plugins not found" > "${LOGDIR}/mu-plugins/_ls.txt"
fi

run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" || true

# ---------- E) Users ----------
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" || true

# ---------- F) SSOT ----------
SSOT_PATH="${TARGET}/.wtp/ssot.yml"
SSOT_SHA1=""; SSOT_B64=""
if [[ -f "$SSOT_PATH" ]]; then
  cp "$SSOT_PATH" "${LOGDIR}/ssot.yml"
  SSOT_SHA1="$(sha1sum "$SSOT_PATH" | awk '{print $1}')"
  echo "$SSOT_SHA1" > "${LOGDIR}/ssot.sha1"
  SSOT_B64="$(base64 -w0 "$SSOT_PATH" || base64 "$SSOT_PATH" | tr -d '\n')"
fi

# ---------- G) Server ----------
SERVER_USER="$(whoami)"
SERVER_UNAME="$(uname -a)"
SERVER_DT="$(date -Is)"
SERVER_CWD="$(cd "$TARGET" && pwd)"
echo -e "user: $SERVER_USER\nuname: $SERVER_UNAME\ndatetime: $SERVER_DT\ncwd: $SERVER_CWD" > "${LOGDIR}/server_info.txt"

# ---------- H) Snapshot JSON ----------
TS_NOW="$(date -Is)"
if [[ "${JQ_OK}" -eq 1 ]]; then
  THEME_ACTIVE_JSON="$(jq 'if type=="array" and length>0 then .[0] else null end' "${LOGDIR}/theme_active.json" 2>/dev/null || echo 'null')"
  jq -n \
    --argjson run_id "$RUN_ID" \
    --arg timestamp "$TS_NOW" \
    --argfile site "${LOGDIR}/site_info.json" \
    --argfile themes_all "${LOGDIR}/themes.json" \
    --argfile plugins_std "${LOGDIR}/plugins.json" \
    --argfile plugins_mu "${LOGDIR}/mu_plugins.json" \
    --argfile admins "${LOGDIR}/admins.json" \
    --slurpfile trees "${PLUG_TREE_SUMMARY}" \
    --arg server_user "$SERVER_USER" \
    --arg server_uname "$SERVER_UNAME" \
    --arg server_datetime "$SERVER_DT" \
    --arg server_cwd "$SERVER_CWD" \
    --arg ssot_path ".wtp/ssot.yml" \
    --arg ssot_sha1 "$SSOT_SHA1" \
    --arg ssot_b64 "$SSOT_B64" \
    --arg theme_active "$THEME_ACTIVE_JSON" \
    '{
      run_id:$run_id,
      timestamp:$timestamp,
      site:$site,
      server:{user:$server_user,uname:$server_uname,datetime:$server_datetime,cwd:$server_cwd},
      theme:{active:(try ($theme_active|fromjson) catch null),all:$themes_all},
      plugins:{standard:$plugins_std,must_use:$plugins_mu,trees:$trees[0]},
      admins:$admins,
      wtp:{ssot_path:$ssot_path,ssot_sha1:$ssot_sha1,ssot_b64:$ssot_b64}
    }' > "${LOGDIR}/snapshot.json"
else
  echo '{"error":"jq missing"}' > "${LOGDIR}/snapshot.json"
fi
