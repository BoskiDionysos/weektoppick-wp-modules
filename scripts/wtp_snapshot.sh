#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${RUN_ID:?RUN_ID is required}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
BINDIR="${TARGET}/.wtp/state/bin"
mkdir -p "${LOGDIR}" "${BINDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

note_err() {
  echo "$1" | tee -a "${ERR_FILE}" 1>&2 || true
}

run_wp() {
  php ./wp "$@" --path="${TARGET}"
}

# ---- ensure jq ----
JQ="${BINDIR}/jq"
if ! command -v jq >/dev/null 2>&1; then
  if [[ ! -x "$JQ" ]]; then
    echo "jq not found, downloading static binary..." >&2
    curl -sSL -o "${JQ}" https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 || {
      note_err "Failed to download jq"
      JQ="/bin/false"
    }
    chmod +x "${JQ}" || true
  fi
else
  JQ="$(command -v jq)"
fi

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
php -v > "${LOGDIR}/php_info.txt" 2>&1 || note_err "php -v failed."

"${JQ}" -n \
  --arg url "${SITE_URL}" \
  --arg home "${SITE_HOME}" \
  --arg wp_version "${WP_VER}" \
  --arg table_prefix "${TABLE_PREFIX}" \
  --arg language "${WPLANG}" \
  --arg timezone "${TZ_STR}" \
  --arg php_version "${PHP_VERSION}" \
  '{
    url: $url,
    home: $home,
    wp_version: $wp_version,
    table_prefix: $table_prefix,
    language: $language,
    timezone: $timezone,
    php_version: $php_version
  }' > "${LOGDIR}/site_info.json" || note_err "Failed to build site_info.json."

# ---------- (dalej kod bez zmian, każde `jq` zastąpione przez "${JQ}") ----------

# ... [tu zostają sekcje themes, plugins, mu-plugins, admins, ssot, summary, final snapshot.json]

# ---------- Final snapshot.json ----------
TS_NOW="$(date -Is)"
"${JQ}" -n \
  --argjson run_id "${RUN_ID}" \
  --arg timestamp "${TS_NOW}" \
  --slurpfile site "${LOGDIR}/site_info.json" \
  --slurpfile themes_all "${LOGDIR}/themes.json" \
  --slurpfile plugins_std "${LOGDIR}/plugins.json" \
  --slurpfile plugins_mu "${LOGDIR}/mu_plugins.json" \
  --slurpfile admins "${LOGDIR}/admins.json" \
  --slurpfile plugs_active "${LOGDIR}/plugins_active.json" \
  --slurpfile counts "${LOGDIR}/counts.json" \
  --slurpfile errors "${LOGDIR}/errors.json" \
  --argjson pluginTrees "$pluginTrees" \
  --argjson muTrees "$muTrees" \
  --argjson muOff "$muOff" \
  --arg ssot_path ".wtp/ssot.yml" \
  --arg ssot_sha1 "${SSOT_SHA1}" \
  --arg ssot_b64 "${SSOT_B64}" \
  '{
    run_id: $run_id,
    timestamp: $timestamp,
    site: $site[0],
    server: {
      user: "'"$SERVER_USER"'",
      uname: "'"$SERVER_UNAME"'",
      datetime: "'"$SERVER_DT"'",
      cwd: "'"$SERVER_CWD"'"
    },
    theme: {
      active: ( $themes_all[0][0]? // null ),
      all: $themes_all[0]
    },
    plugins: {
      standard: $plugins_std[0],
      must_use: $plugins_mu[0],
      trees: $pluginTrees,
      mu_trees: $muTrees,
      mu_off: $muOff
    },
    admins: $admins[0],
    summary: {
      plugins_active: $plugs_active[0],
      counts: $counts[0],
      errors: $errors[0]
    },
    wtp: {
      ssot_path: $ssot_path,
      ssot_sha1: $ssot_sha1,
      ssot_b64: $ssot_b64
    }
  }' > "${LOGDIR}/snapshot.json"

"${JQ}" empty "${LOGDIR}/snapshot.json" || note_err "Malformed snapshot.json"

exit 0
