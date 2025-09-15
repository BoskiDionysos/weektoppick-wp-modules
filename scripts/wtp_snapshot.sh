#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${RUN_ID:?RUN_ID is required}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
mkdir -p "${LOGDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

record_error() {
  echo "$1" | tee -a "${ERR_FILE}" 1>&2 || true
}

run_wp() {
  php ./wp "$@" --path="${TARGET}"
}

# ---------- A) Site/Core ----------
SITE_URL="$(run_wp option get siteurl 2>/dev/null || true)"
SITE_HOME="$(run_wp option get home 2>/dev/null || true)"
WP_VER="$(run_wp core version 2>/dev/null || true)"
TABLE_PREFIX="$(grep -E "^\s*\\\$table_prefix\s*=" "${TARGET}/wp-config.php" 2>/dev/null \
  | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | head -n1 || echo "wp_")"
WPLANG="$(run_wp option get WPLANG 2>/dev/null || true)"
TZ_STR="$(run_wp option get timezone_string 2>/dev/null || true)"
if [[ -z "${TZ_STR}" || "${TZ_STR}" == "false" ]]; then
  TZ_STR="$(run_wp option get gmt_offset 2>/dev/null || true)"
fi
PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"

jq -n \
  --arg url "${SITE_URL}" \
  --arg home "${SITE_HOME}" \
  --arg wp_version "${WP_VER}" \
  --arg table_prefix "${TABLE_PREFIX}" \
  --arg language "${WPLANG}" \
  --arg timezone "${TZ_STR}" \
  --arg php_version "${PHP_VERSION}" \
  '{url:$url,home:$home,wp_version:$wp_version,table_prefix:$table_prefix,language:$language,timezone:$timezone,php_version:$php_version}' \
  > "${LOGDIR}/site_info.json" 2>/dev/null || record_error "Failed to build site_info.json."

# ---------- B) Themes ----------
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/theme_active.json"
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/themes.json"

# Active theme tree & hashes
ACTIVE_THEME=$(jq -r '.[0].stylesheet' "${LOGDIR}/theme_active.json" 2>/dev/null || echo "")
if [[ -n "$ACTIVE_THEME" && -d "$TARGET/wp-content/themes/$ACTIVE_THEME" ]]; then
  mkdir -p "${LOGDIR}/theme"
  (cd "$TARGET/wp-content/themes/$ACTIVE_THEME" && find . -type f | sort) > "${LOGDIR}/theme/tree.txt"
  (cd "$TARGET/wp-content/themes/$ACTIVE_THEME" && find . -type f -exec sha1sum {} \; | sort) > "${LOGDIR}/theme/hashes.sha1"
  THEME_FILES=$(wc -l < "${LOGDIR}/theme/tree.txt" || echo 0)
  THEME_SHA1=$(sha1sum "${LOGDIR}/theme/hashes.sha1" | awk '{print $1}')
else
  THEME_FILES=0
  THEME_SHA1=""
  record_error "active theme directory not found"
fi

# ---------- C) Plugins ----------
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/plugins.json"
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || echo '' > "${LOGDIR}/plugins.csv"

run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/plugins_active.json"
jq -r '.[]' "${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" 2>/dev/null || : > "${LOGDIR}/plugins_active.txt"

# plugin trees
mkdir -p "${LOGDIR}/plugins"
pluginTrees="{}"
for slug in $(jq -r '.[].name' "${LOGDIR}/plugins.json" 2>/dev/null || true); do
  PDIR="${TARGET}/wp-content/plugins/$slug"
  if [[ -d "$PDIR" ]]; then
    mkdir -p "${LOGDIR}/plugins/$slug"
    (cd "$PDIR" && find . -type f | sort) > "${LOGDIR}/plugins/$slug/tree.txt"
    (cd "$PDIR" && find . -type f -exec sha1sum {} \; | sort) > "${LOGDIR}/plugins/$slug/hashes.sha1"
    COUNT=$(wc -l < "${LOGDIR}/plugins/$slug/tree.txt" || echo 0)
    SHA=$(sha1sum "${LOGDIR}/plugins/$slug/hashes.sha1" | awk '{print $1}')
    pluginTrees=$(jq -n --arg slug "$slug" --argjson c "$COUNT" --arg sha "$SHA" \
      --argjson trees "$pluginTrees" '$trees + {($slug):{files:$c,sha1:$sha}}')
  fi
done

# ---------- D) MU-Plugins ----------
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/mu_plugins.json"
MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"
muTrees="{}"
muOff="[]"
if [[ -d "$MU_DIR" ]]; then
  ls -la "$MU_DIR" > "${LOGDIR}/mu-plugins/_ls.txt"
  : > "${LOGDIR}/mu-plugins/_hashes.txt"
  for f in "$MU_DIR"/*; do
    if [[ -f "$f" ]]; then
      if [[ "$f" == *.off ]]; then
        muOff=$(jq -n --arg f "$(basename "$f")" --argjson arr "$muOff" '$arr + [$f]')
      else
        sha1sum "$f" >> "${LOGDIR}/mu-plugins/_hashes.txt"
        slug=$(basename "$f" .php)
        COUNT=1
        SHA=$(sha1sum "$f" | awk '{print $1}')
        muTrees=$(jq -n --arg slug "$slug" --argjson c "$COUNT" --arg sha "$SHA" \
          --argjson trees "$muTrees" '$trees + {($slug):{files:$c,sha1:$sha}}')
      fi
    fi
  done
else
  record_error "mu-plugins directory not found"
fi

# ---------- E) Admins ----------
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/admins.json"

# ---------- F) SSOT ----------
SSOT_PATH="${TARGET}/.wtp/ssot.yml"
SSOT_SHA1=""
SSOT_B64=""
if [[ -f "$SSOT_PATH" ]]; then
  SSOT_SHA1="$(sha1sum "$SSOT_PATH" | awk '{print $1}')"
  SSOT_B64="$(base64 -w0 "$SSOT_PATH" 2>/dev/null || base64 "$SSOT_PATH" | tr -d '\n')"
else
  record_error "SSOT file not found"
fi

# ---------- G) Server info ----------
SERVER_USER="$(whoami 2>/dev/null || true)"
SERVER_UNAME="$(uname -a 2>/dev/null || true)"
SERVER_DT="$(date -Is 2>/dev/null || true)"
SERVER_CWD="$(cd "$TARGET" && pwd 2>/dev/null || true)"

# ---------- H) Counts ----------
THEMES_TOTAL=$(jq 'length' "${LOGDIR}/themes.json" 2>/dev/null || echo 0)
PLUGINS_TOTAL=$(jq 'length' "${LOGDIR}/plugins.json" 2>/dev/null || echo 0)
PLUGINS_ACTIVE_CNT=$(jq 'length' "${LOGDIR}/plugins_active.json" 2>/dev/null || echo 0)
PLUGINS_MU_CNT=$(jq 'length' "${LOGDIR}/mu_plugins.json" 2>/dev/null || echo 0)
ADMINS_CNT=$(jq 'length' "${LOGDIR}/admins.json" 2>/dev/null || echo 0)

jq -n \
  --argjson themes_total "$THEMES_TOTAL" \
  --argjson plugins_total "$PLUGINS_TOTAL" \
  --argjson plugins_active "$PLUGINS_ACTIVE_CNT" \
  --argjson plugins_mu "$PLUGINS_MU_CNT" \
  --argjson admins "$ADMINS_CNT" \
  '{themes_total:$themes_total,plugins_total:$plugins_total,plugins_active:$plugins_active,plugins_mu:$plugins_mu,admins:$admins}' \
  > "${LOGDIR}/counts.json" 2>/dev/null || echo '{}' > "${LOGDIR}/counts.json"

# ---------- I) Build snapshot.json ----------
TS_NOW="$(date -Is)"
SNAP="${LOGDIR}/snapshot.json"

cat > "$SNAP" <<EOF
{
  "run_id": ${RUN_ID},
  "timestamp": "${TS_NOW}",
  "site": $(cat "${LOGDIR}/site_info.json"),
  "server": {
    "user": "${SERVER_USER}",
    "uname": "${SERVER_UNAME}",
    "datetime": "${SERVER_DT}",
    "cwd": "${SERVER_CWD}"
  },
  "theme": {
    "active": $(cat "${LOGDIR}/theme_active.json"),
    "all": $(cat "${LOGDIR}/themes.json"),
    "tree": { "files": ${THEME_FILES}, "sha1": "${THEME_SHA1}" }
  },
  "plugins": {
    "standard": $(cat "${LOGDIR}/plugins.json"),
    "must_use": $(cat "${LOGDIR}/mu_plugins.json"),
    "trees": $pluginTrees,
    "mu_trees": $muTrees,
    "mu_off": $muOff
  },
  "admins": $(cat "${LOGDIR}/admins.json"),
  "summary": {
    "plugins_active": $(cat "${LOGDIR}/plugins_active.json"),
    "counts": $(cat "${LOGDIR}/counts.json"),
    "errors": $(jq -Rs 'split("\n")|map(select(length>0))' "${ERR_FILE}" 2>/dev/null || echo '[]')
  },
  "wtp": {
    "ssot_path": ".wtp/ssot.yml",
    "ssot_sha1": "${SSOT_SHA1}",
    "ssot_b64": "${SSOT_B64}"
  }
}
EOF

# validate
if command -v jq >/dev/null 2>&1; then
  jq empty "$SNAP" || echo "WARNING: Malformed JSON"
fi

exit 0
