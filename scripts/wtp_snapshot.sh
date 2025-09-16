#!/usr/bin/env bash
# scripts/wtp_snapshot.sh
set -euo pipefail

# ---------- Guard ----------
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

# table_prefix from wp-config.php (tolerant)
TABLE_PREFIX="$(grep -E "^\s*\\\$table_prefix\s*=" "${TARGET}/wp-config.php" 2>/dev/null \
  | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | head -n1 || echo "wp_")"

WPLANG="$(run_wp option get WPLANG 2>/dev/null || true)"
TZ_STR="$(run_wp option get timezone_string 2>/dev/null || true)"
if [[ -z "${TZ_STR}" || "${TZ_STR}" == "false" ]]; then
  TZ_STR="$(run_wp option get gmt_offset 2>/dev/null || true)"
fi

PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
php -v > "${LOGDIR}/php_info.txt" 2>&1 || note_err "php -v failed."

# site_info.json
{
  echo '{'
  echo "\"url\":\"${SITE_URL}\","
  echo "\"home\":\"${SITE_HOME}\","
  echo "\"wp_version\":\"${WP_VER}\","
  echo "\"table_prefix\":\"${TABLE_PREFIX}\","
  echo "\"language\":\"${WPLANG}\","
  echo "\"timezone\":\"${TZ_STR}\","
  echo "\"php_version\":\"${PHP_VERSION}\""
  echo '}'
} > "${LOGDIR}/site_info.json" || note_err "Failed to build site_info.json."

# ---------- B) Theme(s) ----------
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || note_err "wp theme list --status=active failed."
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || note_err "wp theme list --format=json failed."

# ACTIVE theme dir (for entry points)
ACTIVE_THEME_SLUG="$(run_wp theme list --status=active --field=name --format=csv 2>/dev/null || true)"
ACTIVE_THEME_DIR="${TARGET}/wp-content/themes/${ACTIVE_THEME_SLUG}"

# ---------- C) Plugins ----------
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=json failed."
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=csv failed."

# MU-plugins
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --status=must-use failed."

MU_DIR="${TARGET}/wp-content/mu-plugins"
if [[ -d "${MU_DIR}" ]]; then
  ls -la "${MU_DIR}" > "${LOGDIR}/mu_plugins_ls.txt" 2>>"${ERR_FILE}" || note_err "ls mu-plugins failed."
  : > "${LOGDIR}/mu_plugins_hashes.txt"
  while IFS= read -r -d '' f; do
    sha1sum "${f}" >> "${LOGDIR}/mu_plugins_hashes.txt" 2>>"${ERR_FILE}" || note_err "sha1sum failed for ${f}."
  done < <(find "${MU_DIR}" -type f -print0 2>/dev/null || true)

  : > "${LOGDIR}/mu_plugins_headers.txt"
  while IFS= read -r -d '' fphp; do
    head -n 50 "${fphp}" | grep -E "^\s*\*\s*Plugin Name:" -m1 >> "${LOGDIR}/mu_plugins_headers.txt" 2>>"${ERR_FILE}" || true
  done < <(find "${MU_DIR}" -maxdepth 1 -type f -name "*.php" -print0 2>/dev/null || true)
else
  echo "mu-plugins directory not found." > "${LOGDIR}/mu_plugins_ls.txt"
  : > "${LOGDIR}/mu_plugins_hashes.txt"
  : > "${LOGDIR}/mu_plugins_headers.txt"
  note_err "wp-content/mu-plugins/ not found."
fi

# ---------- D) Users (admins) ----------
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || note_err "wp user list --role=administrator failed."

# ---------- E) WTP / SSOT ----------
SSOT_PATH_REL=".wtp/ssot.yml"
SSOT_PATH="${TARGET}/${SSOT_PATH_REL}"
SSOT_SHA1=""
SSOT_B64=""

if [[ -f "${SSOT_PATH}" ]]; then
  cp "${SSOT_PATH}" "${LOGDIR}/ssot.yml" 2>>"${ERR_FILE}" || note_err "Copy ssot.yml failed."
  SSOT_SHA1="$(sha1sum "${SSOT_PATH}" | awk '{print $1}' 2>/dev/null || true)"
  echo "${SSOT_SHA1}" > "${LOGDIR}/ssot.sha1" || note_err "Write ssot.sha1 failed."
  SSOT_B64="$(base64 -w0 "${SSOT_PATH}" 2>/dev/null || base64 "${SSOT_PATH}" | tr -d '\n' || true)"
else
  note_err "SSOT file ${SSOT_PATH_REL} not found."
fi

# ---------- F) Server info ----------
SERVER_USER="$(whoami 2>/dev/null || true)"
SERVER_UNAME="$(uname -a 2>/dev/null || true)"
SERVER_DT="$(date -Is 2>/dev/null || true)"
SERVER_CWD="$(cd "${TARGET}" && pwd 2>/dev/null || true)"

{
  echo "user: ${SERVER_USER}"
  echo "uname: ${SERVER_UNAME}"
  echo "datetime: ${SERVER_DT}"
  echo "cwd: ${SERVER_CWD}"
} > "${LOGDIR}/server_info.txt" || note_err "Write server_info.txt failed."

# ---------- G) Summary lists ----------
run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --status=active --field=name failed."
if [[ -s "${LOGDIR}/plugins_active.json" ]]; then
  jq -r '.[]' "${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" 2>>"${ERR_FILE}" || note_err "Build plugins_active.txt failed."
else
  : > "${LOGDIR}/plugins_active.txt"
fi

THEMES_TOTAL="$(jq 'length' "${LOGDIR}/themes.json" 2>/dev/null || echo 0)"
PLUGINS_TOTAL="$(jq 'length' "${LOGDIR}/plugins.json" 2>/dev/null || echo 0)"
PLUGINS_ACTIVE_CNT="$(jq 'length' "${LOGDIR}/plugins_active.json" 2>/dev/null || echo 0)"
PLUGINS_MU_CNT="$(jq 'length' "${LOGDIR}/mu_plugins.json" 2>/dev/null || echo 0)"
ADMINS_CNT="$(jq 'length' "${LOGDIR}/admins.json" 2>/dev/null || echo 0)"

jq -n --argjson themes_total "${THEMES_TOTAL}" \
      --argjson plugins_total "${PLUGINS_TOTAL}" \
      --argjson plugins_active "${PLUGINS_ACTIVE_CNT}" \
      --argjson plugins_mu "${PLUGINS_MU_CNT}" \
      --argjson admins "${ADMINS_CNT}" \
      '{themes_total:$themes_total, plugins_total:$plugins_total, plugins_active:$plugins_active, plugins_mu:$plugins_mu, admins:$admins}' \
      > "${LOGDIR}/counts.json" 2>/dev/null || echo '{}' > "${LOGDIR}/counts.json"

# ---------- H) Errors as JSON ----------
if [[ -s "${ERR_FILE}" ]]; then
  jq -Rs 'split("\n") | map(select(length>0))' "${ERR_FILE}" > "${LOGDIR}/errors.json" 2>/dev/null || echo '[]' > "${LOGDIR}/errors.json"
else
  echo '[]' > "${LOGDIR}/errors.json"
fi

# ---------- NEW: Options (UX/SEO) ----------
OPTS_JSON="${LOGDIR}/options_core.json"
{
  echo '{'
  echo '"permalink_structure": '  "\"$(run_wp option get permalink_structure 2>/dev/null || true)\"", 
  echo '"blogname": '             "\"$(run_wp option get blogname 2>/dev/null || true)\"", 
  echo '"blogdescription": '      "\"$(run_wp option get blogdescription 2>/dev/null || true)\"", 
  echo '"show_on_front": '        "\"$(run_wp option get show_on_front 2>/dev/null || true)\"", 
  echo '"page_on_front": '        "\"$(run_wp option get page_on_front 2>/dev/null || true)\"",
  echo '"timezone_string": '      "\"$(run_wp option get timezone_string 2>/dev/null || true)\"",
  echo '"WPLANG": '               "\"$(run_wp option get WPLANG 2>/dev/null || true)\""
  echo '}'
} > "${OPTS_JSON}" || echo '{}' > "${OPTS_JSON}"

# ---------- NEW: Menus & locations ----------
run_wp menu list --format=json > "${LOGDIR}/menus.json" 2>/dev/null || echo '[]' > "${LOGDIR}/menus.json"
run_wp menu location list --format=json > "${LOGDIR}/menu_locations.json" 2>/dev/null || echo '[]' > "${LOGDIR}/menu_locations.json"

: > "${LOGDIR}/menus_full.json"
{
  echo '{'
  first=1
  for mid in $(run_wp menu list --field=term_id --format=csv 2>/dev/null || true); do
    [ -n "$mid" ] || continue
    items="$(run_wp menu item list "${mid}" --format=json 2>/dev/null || echo '[]')"
    name="$(run_wp menu list --format=json 2>/dev/null | jq -r ".[]|select(.term_id==${mid})|.name" 2>/dev/null || echo "")"
    [ $first -ne 1 ] && echo ','
    first=0
    printf '"%s": %s' "${name:-menu_${mid}}" "${items}"
  done
  echo '}'
} >> "${LOGDIR}/menus_full.json" 2>/dev/null || echo '{}' > "${LOGDIR}/menus_full.json"

# ---------- NEW: Taxonomies & counts ----------
run_wp taxonomy list --format=json > "${LOGDIR}/taxonomies.json" 2>/dev/null || echo '[]' > "${LOGDIR}/taxonomies.json"

: > "${LOGDIR}/taxonomy_counts.json"
{
  echo '{'
  first=1
  for tax in $(run_wp taxonomy list --field=name --format=csv 2>/dev/null || true); do
    [ -n "$tax" ] || continue
    cnt="$(run_wp term list "$tax" --format=csv 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo 0)"
    [ $first -ne 1 ] && echo ','
    first=0
    printf '"%s": %s' "$tax" "${cnt:-0}"
  done
  echo '}'
} >> "${LOGDIR}/taxonomy_counts.json" 2>/dev/null || echo '{}' > "${LOGDIR}/taxonomy_counts.json"

# ---------- NEW: Theme entry points ----------
TPJSON="${LOGDIR}/theme_entrypoints.json"
declare -a TP=( front-page.php home.php index.php page.php single.php archive.php category.php tag.php date.php author.php search.php 404.php )
{
  echo '{'
  first=1
  for f in "${TP[@]}"; do
    present="false"
    [[ -n "${ACTIVE_THEME_SLUG}" && -f "${ACTIVE_THEME_DIR}/${f}" ]] && present="true"
    [ $first -ne 1 ] && echo ','
    first=0
    printf '"%s": %s' "$f" "$present"
  done
  echo '}'
} > "${TPJSON}" 2>/dev/null || echo '{}' > "${TPJSON}"

# ---------- Build snapshot.json ----------
THEME_ACTIVE_JSON="$(jq 'if type=="array" and length>0 then .[0] else null end' "${LOGDIR}/theme_active.json" 2>/dev/null || echo 'null')"
TS_NOW="$(date -Is)"

# Ensure files exist with defaults
[[ -f "${LOGDIR}/site_info.json" ]] || echo '{}' > "${LOGDIR}/site_info.json"
[[ -f "${LOGDIR}/themes.json" ]] || echo '[]' > "${LOGDIR}/themes.json"
[[ -f "${LOGDIR}/plugins.json" ]] || echo '[]' > "${LOGDIR}/plugins.json"
[[ -f "${LOGDIR}/mu_plugins.json" ]] || echo '[]' > "${LOGDIR}/mu_plugins.json"
[[ -f "${LOGDIR}/admins.json" ]] || echo '[]' > "${LOGDIR}/admins.json"
[[ -f "${LOGDIR}/plugins_active.json" ]] || echo '[]' > "${LOGDIR}/plugins_active.json"
[[ -f "${LOGDIR}/counts.json" ]] || echo '{}' > "${LOGDIR}/counts.json"
[[ -f "${LOGDIR}/errors.json" ]] || echo '[]' > "${LOGDIR}/errors.json"
[[ -f "${LOGDIR}/options_core.json" ]] || echo '{}' > "${LOGDIR}/options_core.json"
[[ -f "${LOGDIR}/menus.json" ]] || echo '[]' > "${LOGDIR}/menus.json"
[[ -f "${LOGDIR}/menu_locations.json" ]] || echo '[]' > "${LOGDIR}/menu_locations.json"
[[ -f "${LOGDIR}/menus_full.json" ]] || echo '{}' > "${LOGDIR}/menus_full.json"
[[ -f "${LOGDIR}/taxonomies.json" ]] || echo '[]' > "${LOGDIR}/taxonomies.json"
[[ -f "${LOGDIR}/taxonomy_counts.json" ]] || echo '{}' > "${LOGDIR}/taxonomy_counts.json"
[[ -f "${LOGDIR}/theme_entrypoints.json" ]] || echo '{}' > "${LOGDIR}/theme_entrypoints.json"

if command -v jq >/dev/null 2>&1; then
  if ! jq -n \
    --argjson run_id "${RUN_ID}" \
    --arg timestamp "${TS_NOW}" \
    --argfile site            "${LOGDIR}/site_info.json" \
    --argfile themes_all      "${LOGDIR}/themes.json" \
    --argfile plugins_std     "${LOGDIR}/plugins.json" \
    --argfile plugins_mu      "${LOGDIR}/mu_plugins.json" \
    --argfile admins          "${LOGDIR}/admins.json" \
    --argfile plugs_active    "${LOGDIR}/plugins_active.json" \
    --argfile counts          "${LOGDIR}/counts.json" \
    --argfile errors          "${LOGDIR}/errors.json" \
    --argfile options_core    "${LOGDIR}/options_core.json" \
    --argfile menus           "${LOGDIR}/menus.json" \
    --argfile menu_locations  "${LOGDIR}/menu_locations.json" \
    --argfile menus_full      "${LOGDIR}/menus_full.json" \
    --argfile taxonomies      "${LOGDIR}/taxonomies.json" \
    --argfile taxonomy_counts "${LOGDIR}/taxonomy_counts.json" \
    --argfile theme_entry     "${LOGDIR}/theme_entrypoints.json" \
    --arg theme_active "${THEME_ACTIVE_JSON}" \
    --arg server_user "${SERVER_USER}" \
    --arg server_uname "${SERVER_UNAME}" \
    --arg server_datetime "${SERVER_DT}" \
    --arg server_cwd "${SERVER_CWD}" \
    --arg ssot_path ".wtp/ssot.yml" \
    --arg ssot_sha1 "${SSOT_SHA1}" \
    --arg ssot_b64 "${SSOT_B64}" \
    '{
      run_id: $run_id,
      timestamp: $timestamp,
      site: ($site + { options: $options_core }),
      server: { user: $server_user, uname: $server_uname, datetime: $server_datetime, cwd: $server_cwd },
      theme:  { active: (try ($theme_active | fromjson) catch null), all: $themes_all, entry_points: $theme_entry },
      plugins:{ standard: $plugins_std, must_use: $plugins_mu },
      admins: $admins,
      nav:    { menus: $menus, menu_locations: $menu_locations, menus_full: $menus_full },
      content:{ taxonomies: $taxonomies, taxonomy_counts: $taxonomy_counts },
      summary:{ plugins_active: $plugs_active, counts: $counts, errors: $errors },
      wtp:    { ssot_path: $ssot_path, ssot_sha1: $ssot_sha1, ssot_b64: $ssot_b64 }
    }' > "${LOGDIR}/snapshot.json"; then
      note_err "jq aggregation failed – using minimal fallback."
      echo "{\"run_id\":${RUN_ID},\"timestamp\":\"${TS_NOW}\"}" > "${LOGDIR}/snapshot.json"
  fi
else
  note_err "jq not found – using minimal snapshot."
  echo "{\"run_id\":${RUN_ID},\"timestamp\":\"${TS_NOW}\"}" > "${LOGDIR}/snapshot.json"
fi
