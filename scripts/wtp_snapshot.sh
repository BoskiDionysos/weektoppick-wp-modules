#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${RUN_ID:?RUN_ID is required}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
mkdir -p "${LOGDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

note_err() {
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
php -v > "${LOGDIR}/php_info.txt" 2>&1 || note_err "php -v failed."

jq -n \
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

# ---------- B) Themes ----------
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || true
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || true

# Active theme tree/hash
ACTIVE_THEME="$(jq -r '.[0].stylesheet // empty' "${LOGDIR}/theme_active.json" 2>/dev/null || echo '')"
if [[ -n "${ACTIVE_THEME}" && -d "${TARGET}/wp-content/themes/${ACTIVE_THEME}" ]]; then
  THEME_DIR="${TARGET}/wp-content/themes/${ACTIVE_THEME}"
  mkdir -p "${LOGDIR}/theme/${ACTIVE_THEME}"
  find "${THEME_DIR}" -type f | sed "s|${TARGET}/||" > "${LOGDIR}/theme/${ACTIVE_THEME}/tree.txt" || true
  (cd "${TARGET}" && find "wp-content/themes/${ACTIVE_THEME}" -type f -exec sha1sum {} \;) > "${LOGDIR}/theme/${ACTIVE_THEME}/hashes.sha1" || true
fi

# ---------- C) Plugins ----------
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || true
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || true

# per-plugin tree/hash
mkdir -p "${LOGDIR}/plugins"
pluginTrees="{}"
if [[ -s "${LOGDIR}/plugins.json" ]]; then
  for slug in $(jq -r '.[].name' "${LOGDIR}/plugins.json"); do
    PDIR="${TARGET}/wp-content/plugins/${slug}"
    if [[ -d "${PDIR}" ]]; then
      mkdir -p "${LOGDIR}/plugins/${slug}"
      find "${PDIR}" -type f | sed "s|${TARGET}/||" > "${LOGDIR}/plugins/${slug}/tree.txt" || true
      (cd "${TARGET}" && find "wp-content/plugins/${slug}" -type f -exec sha1sum {} \;) > "${LOGDIR}/plugins/${slug}/hashes.sha1" || true
      count=$(wc -l < "${LOGDIR}/plugins/${slug}/tree.txt" || echo 0)
      sha=$(sha1sum "${LOGDIR}/plugins/${slug}/hashes.sha1" | awk '{print $1}' || echo "")
      pluginTrees=$(jq --arg slug "$slug" --argjson count "$count" --arg sha "$sha" '. + {($slug): {files:$count, sha1:$sha}}' <<<"$pluginTrees")
    fi
  done
fi

# ---------- D) MU-plugins ----------
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || true

MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"
muTrees="{}"
muOff="[]"
if [[ -d "${MU_DIR}" ]]; then
  ls -la "${MU_DIR}" > "${LOGDIR}/mu-plugins/_ls.txt" || true
  : > "${LOGDIR}/mu-plugins/_hashes.txt"
  while IFS= read -r -d '' f; do
    sha1sum "${f}" >> "${LOGDIR}/mu-plugins/_hashes.txt" || true
  done < <(find "${MU_DIR}" -type f -print0 2>/dev/null || true)

  for f in "${MU_DIR}"/*.php*; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f")
    slug="${base%.*}"
    mkdir -p "${LOGDIR}/mu-plugins/${slug}"
    if [[ "$f" == *.php ]]; then
      head -n 50 "$f" | grep -E "^\s*\*\s*Plugin Name:" -m1 > "${LOGDIR}/mu-plugins/${slug}/header.txt" || true
      find "$f" -type f | sed "s|${TARGET}/||" > "${LOGDIR}/mu-plugins/${slug}/tree.txt" || true
      (cd "${TARGET}" && sha1sum "wp-content/mu-plugins/${base}") > "${LOGDIR}/mu-plugins/${slug}/hashes.sha1" || true
      muTrees=$(jq --arg slug "$slug" --arg sha "$(sha1sum "$f" | awk '{print $1}')" '. + {($slug): {files:1, sha1:$sha}}' <<<"$muTrees")
    else
      muOff=$(jq --arg base "$base" '. + [$base]' <<<"$muOff")
    fi
  done
else
  echo "mu-plugins directory not found." > "${LOGDIR}/mu-plugins/_ls.txt"
fi

# ---------- E) Admin users ----------
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || true

# ---------- F) WTP/SSOT ----------
SSOT_PATH_REL=".wtp/ssot.yml"
SSOT_PATH="${TARGET}/${SSOT_PATH_REL}"
SSOT_SHA1=""
SSOT_B64=""
if [[ -f "${SSOT_PATH}" ]]; then
  cp "${SSOT_PATH}" "${LOGDIR}/ssot.yml" || true
  SSOT_SHA1="$(sha1sum "${SSOT_PATH}" | awk '{print $1}' || true)"
  echo "${SSOT_SHA1}" > "${LOGDIR}/ssot.sha1" || true
  SSOT_B64="$(base64 -w0 "${SSOT_PATH}" 2>/dev/null || base64 "${SSOT_PATH}" | tr -d '\n' || true)"
else
  note_err "SSOT file ${SSOT_PATH_REL} not found."
fi

# ---------- G) Server info ----------
SERVER_USER="$(whoami || true)"
SERVER_UNAME="$(uname -a || true)"
SERVER_DT="$(date -Is || true)"
SERVER_CWD="$(cd "${TARGET}" && pwd || true)"
{
  echo "user: ${SERVER_USER}"
  echo "uname: ${SERVER_UNAME}"
  echo "datetime: ${SERVER_DT}"
  echo "cwd: ${SERVER_CWD}"
} > "${LOGDIR}/server_info.txt" || true

# ---------- H) Summary ----------
run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" 2>>"${ERR_FILE}" || true
jq -r '.[]' "${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" || true

THEMES_TOTAL="$(jq 'length' "${LOGDIR}/themes.json" 2>/dev/null || echo 0)"
PLUGINS_TOTAL="$(jq 'length' "${LOGDIR}/plugins.json" 2>/dev/null || echo 0)"
PLUGINS_ACTIVE_CNT="$(jq 'length' "${LOGDIR}/plugins_active.json" 2>/dev/null || echo 0)"
PLUGINS_MU_CNT="$(jq 'length' "${LOGDIR}/mu_plugins.json" 2>/dev/null || echo 0)"
ADMINS_CNT="$(jq 'length' "${LOGDIR}/admins.json" 2>/dev/null || echo 0)"

jq -n --argjson themes_total "$THEMES_TOTAL" \
      --argjson plugins_total "$PLUGINS_TOTAL" \
      --argjson plugins_active "$PLUGINS_ACTIVE_CNT" \
      --argjson plugins_mu "$PLUGINS_MU_CNT" \
      --argjson admins "$ADMINS_CNT" \
      '{themes_total:$themes_total, plugins_total:$plugins_total, plugins_active:$plugins_active, plugins_mu:$plugins_mu, admins:$admins}' \
      > "${LOGDIR}/counts.json" || true

if [[ -s "${ERR_FILE}" ]]; then
  jq -Rs 'split("\n") | map(select(length>0))' "${ERR_FILE}" > "${LOGDIR}/errors.json" || echo '[]' > "${LOGDIR}/errors.json"
else
  echo '[]' > "${LOGDIR}/errors.json"
fi

# ---------- Final snapshot.json ----------
TS_NOW="$(date -Is)"
jq -n \
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
  --argjson theme_tree "$(jq -n --arg theme "$ACTIVE_THEME" \
                          --slurpfile t "${LOGDIR}/theme/${ACTIVE_THEME}/tree.txt" \
                          --slurpfile h "${LOGDIR}/theme/${ACTIVE_THEME}/hashes.sha1" \
                          '{($theme): {files: ( $t|length ), sha1: ( $h[0] // "" )}}')" \
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
      all: $themes_all[0],
      tree: $theme_tree
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

# Validate JSON if possible
if command -v jq >/dev/null 2>&1; then
  jq empty "${LOGDIR}/snapshot.json" || echo "WARNING: Malformed snapshot.json"
fi

exit 0
