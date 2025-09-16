#!/usr/bin/env bash
# WTP – Snapshot full state (core, themes, plugins, MU, users, server, SSOT)
# Idempotent, tolerant to missing bits; produces logs + snapshot.json
set -euo pipefail

# ----------- ENV + guards -----------
: "${TARGET:?TARGET is required}"
: "${RUN_ID:?RUN_ID is required}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
mkdir -p "${LOGDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

note_err() {
  # Loguj i nie przerywaj wykonania
  echo "$1" | tee -a "${ERR_FILE}" 1>&2 || true
}

# wrapper na WP-CLI
run_wp() {
  php ./wp "$@" --path="${TARGET}"
}

# Bezpieczny grep table_prefix
read_table_prefix() {
  local prefix
  prefix="$(grep -E "^\s*\\\$table_prefix\s*=" "${TARGET}/wp-config.php" 2>/dev/null \
    | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | head -n1 || true)"
  if [[ -z "${prefix}" ]]; then
    echo "wp_"
  else
    echo "${prefix}"
  fi
}

# JSON helpers (wymagamy jq, ale mamy fallback minimal)
have_jq=1
if ! command -v jq >/dev/null 2>&1; then
  have_jq=0
  note_err "jq not found – JSON aggregation will use minimal fallback."
fi

# ----------- A) Site/Core -----------
SITE_URL="$(run_wp option get siteurl 2>/dev/null || true)"
SITE_HOME="$(run_wp option get home 2>/dev/null || true)"
WP_VER="$(run_wp core version 2>/dev/null || true)"
TABLE_PREFIX="$(read_table_prefix)"
WPLANG="$(run_wp option get WPLANG 2>/dev/null || true)"
TZ_STR="$(run_wp option get timezone_string 2>/dev/null || true)"
if [[ -z "${TZ_STR}" || "${TZ_STR}" == "false" ]]; then
  TZ_STR="$(run_wp option get gmt_offset 2>/dev/null || true)"
fi

PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
php -v > "${LOGDIR}/php_info.txt" 2>&1 || note_err "php -v failed."

# site_info.json
if [[ ${have_jq} -eq 1 ]]; then
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
else
  cat > "${LOGDIR}/site_info.json" <<EOF
{"url":"${SITE_URL}","home":"${SITE_HOME}","wp_version":"${WP_VER}","table_prefix":"${TABLE_PREFIX}","language":"${WPLANG}","timezone":"${TZ_STR}","php_version":"${PHP_VERSION}"}
EOF
fi

# ----------- G) Server info (wcześniej, bo używamy w snapshot) -----------
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

# ----------- B) Theme(s) -----------
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || note_err "wp theme list --status=active failed."
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || note_err "wp theme list --format=json failed."

# Ustal aktywny motyw (slug) i path
ACTIVE_THEME_SLUG=""
if [[ -s "${LOGDIR}/theme_active.json" ]]; then
  # theme list --status=active zwraca array; bierzemy pierwszy element
  ACTIVE_THEME_SLUG="$(jq -r '.[0].stylesheet // empty' "${LOGDIR}/theme_active.json" 2>/dev/null || true)"
fi
# Fallback: z opcji 'stylesheet'
if [[ -z "${ACTIVE_THEME_SLUG}" ]]; then
  ACTIVE_THEME_SLUG="$(run_wp option get stylesheet 2>/dev/null || true)"
fi

THEME_DIR=""
if [[ -n "${ACTIVE_THEME_SLUG}" ]]; then
  THEME_DIR="${TARGET}/wp-content/themes/${ACTIVE_THEME_SLUG}"
  if [[ -d "${THEME_DIR}" ]]; then
    # drzewo motywu i sha1
    THEME_OUT_DIR="${LOGDIR}/theme"
    mkdir -p "${THEME_OUT_DIR}"
    find "${THEME_DIR}" -type f -printf '%P\n' | sort > "${THEME_OUT_DIR}/tree.txt" 2>>"${ERR_FILE}" || note_err "theme tree failed."
    # globalna suma po posortowanych sha1
    ( cd "${THEME_DIR}" && find . -type f -print0 | sort -z | xargs -0 sha1sum ) > "${THEME_OUT_DIR}/hashes.sha1" 2>>"${ERR_FILE}" || true
    if [[ -s "${THEME_OUT_DIR}/hashes.sha1" ]]; then
      awk '{print $1}' "${THEME_OUT_DIR}/hashes.sha1" | tr -d '\r' | sort | sha1sum | awk '{print $1}' > "${THEME_OUT_DIR}/hash_all.txt" 2>>"${ERR_FILE}" || true
    else
      : > "${THEME_OUT_DIR}/hash_all.txt"
    fi
  else
    note_err "active theme directory not found: ${THEME_DIR}"
  fi
else
  note_err "active theme slug not found (db may be empty)."
fi

# ----------- C) Plugins (standard) -----------
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=json failed."
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=csv failed."

# ----------- D) MU-plugins -----------
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --status=must-use failed."
MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"
if [[ -d "${MU_DIR}" ]]; then
  ls -la "${MU_DIR}" > "${LOGDIR}/mu-plugins/_ls.txt" 2>>"${ERR_FILE}" || note_err "ls mu-plugins failed."
  # globalny hash i listing plików MU
  ( cd "${MU_DIR}" && find . -type f -print0 | sort -z | xargs -0 sha1sum ) > "${LOGDIR}/mu-plugins/_hashes.txt" 2>>"${ERR_FILE}" || true
  # nagłówki z plików php (Plugin Name)
  while IFS= read -r -d '' fphp; do
    { echo "=== ${fphp} ==="; head -n 60 "${fphp}" | grep -E "^\s*(\*|//)?\s*Plugin Name:" -m1 || true; echo; } \
      >> "${LOGDIR}/mu-plugins/headers.txt" 2>>"${ERR_FILE}" || true
  done < <(find "${MU_DIR}" -maxdepth 1 -type f -name "*.php" -print0 2>/dev/null || true)
else
  echo "mu-plugins directory not found." > "${LOGDIR}/mu-plugins/_ls.txt"
  : > "${LOGDIR}/mu-plugins/_hashes.txt"
  : > "${LOGDIR}/mu-plugins/headers.txt"
  note_err "wp-content/mu-plugins/ not found."
fi

# ----------- E) Users (admins) -----------
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || note_err "wp user list --role=administrator failed."

# ----------- F) WTP / SSOT -----------
SSOT_PATH_REL=".wtp/ssot.yml"
SSOT_PATH="${TARGET}/${SSOT_PATH_REL}"
SSOT_SHA1=""
SSOT_B64=""
if [[ -f "${SSOT_PATH}" ]]; then
  cp "${SSOT_PATH}" "${LOGDIR}/ssot.yml" 2>>"${ERR_FILE}" || note_err "Copy ssot.yml failed."
  SSOT_SHA1="$(sha1sum "${SSOT_PATH}" | awk '{print $1}' 2>/dev/null || true)"
  echo "${SSOT_SHA1}" > "${LOGDIR}/ssot.sha1" || note_err "Write ssot.sha1 failed."
  # base64 kompatybilnie dla różnych base64 (GNU/BusyBox)
  SSOT_B64="$( (base64 -w0 "${SSOT_PATH}" 2>/dev/null || base64 "${SSOT_PATH}") | tr -d '\n' || true)"
else
  note_err "SSOT file ${SSOT_PATH_REL} not found."
fi

# ----------- H) Summary + counts -----------
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

if [[ ${have_jq} -eq 1 ]]; then
  jq -n --argjson themes_total "${THEMES_TOTAL}" \
        --argjson plugins_total "${PLUGINS_TOTAL}" \
        --argjson plugins_active "${PLUGINS_ACTIVE_CNT}" \
        --argjson plugins_mu "${PLUGINS_MU_CNT}" \
        --argjson admins "${ADMINS_CNT}" \
        '{themes_total:$themes_total, plugins_total:$plugins_total, plugins_active:$plugins_active, plugins_mu:$plugins_mu, admins:$admins}' \
        > "${LOGDIR}/counts.json" || note_err "Build counts.json failed."
else
  echo "{\"themes_total\":${THEMES_TOTAL},\"plugins_total\":${PLUGINS_TOTAL},\"plugins_active\":${PLUGINS_ACTIVE_CNT},\"plugins_mu\":${PLUGINS_MU_CNT},\"admins\":${ADMINS_CNT}}" > "${LOGDIR}/counts.json"
fi

# ----------- NEW: Trees + hashes for EACH plugin (standard) -----------
PLUG_DIR="${TARGET}/wp-content/plugins"
OUT_PLUG_DIR="${LOGDIR}/plugins"
mkdir -p "${OUT_PLUG_DIR}"

# map (slug -> {files, sha1}) jako JSON
if [[ ${have_jq} -eq 1 ]]; then
  echo "{}" > "${LOGDIR}/plugins_trees.json"
else
  echo "{}" > "${LOGDIR}/plugins_trees.json"
fi
: > "${LOGDIR}/plugins_trees.tsv"

# Zbierz listę slugów z plugins.json
if [[ -s "${LOGDIR}/plugins.json" && -d "${PLUG_DIR}" ]]; then
  while IFS= read -r slug; do
    [[ -z "${slug}" ]] && continue
    pdir="${PLUG_DIR}/${slug}"
    dest="${OUT_PLUG_DIR}/${slug}"
    if [[ -d "${pdir}" ]]; then
      mkdir -p "${dest}"
      # tree + hashes
      ( cd "${pdir}" && find . -type f -printf '%P\n' | sort ) > "${dest}/tree.txt" 2>>"${ERR_FILE}" || true
      ( cd "${pdir}" && find . -type f -print0 | sort -z | xargs -0 sha1sum ) > "${dest}/hashes.sha1" 2>>"${ERR_FILE}" || true
      files_count=$(wc -l < "${dest}/tree.txt" 2>/dev/null || echo 0)
      sha_all=""
      if [[ -s "${dest}/hashes.sha1" ]]; then
        sha_all="$(awk '{print $1}' "${dest}/hashes.sha1" | tr -d '\r' | sort | sha1sum | awk '{print $1}')"
      fi
      printf "%s\t%s\t%s\n" "${slug}" "${files_count}" "${sha_all}" >> "${LOGDIR}/plugins_trees.tsv"
      if [[ ${have_jq} -eq 1 ]]; then
        # plugins_trees.json update
        tmp="$(mktemp)"
        jq --arg s "${slug}" --argjson f ${files_count:-0} --arg sha "${sha_all}" \
           '. + {($s): {files:$f, sha1:$sha}}' "${LOGDIR}/plugins_trees.json" > "${tmp}" \
           && mv "${tmp}" "${LOGDIR}/plugins_trees.json" || note_err "jq update plugins_trees.json failed for ${slug}"
      fi
    else
      note_err "plugin dir missing: ${slug}"
    fi
  done < <(jq -r '.[]?.name // empty' "${LOGDIR}/plugins.json" 2>/dev/null || true)
else
  note_err "plugins.json empty or plugins dir missing; skipping per-plugin trees."
fi

# Nie traktuj pustego TSV jako fail
if [[ ! -s "${LOGDIR}/plugins_trees.tsv" ]]; then
  echo -e "slug\tfiles\tsha1" > "${LOGDIR}/plugins_trees.tsv"
  note_err "plugins_trees.tsv is empty (no plugin file trees captured)."
fi

# ----------- Build snapshot.json -----------
TS_NOW="$(date -Is)"

# Bezpieczne istnienie plików
[[ -f "${LOGDIR}/site_info.json" ]] || echo '{}' > "${LOGDIR}/site_info.json"
[[ -f "${LOGDIR}/themes.json" ]] || echo '[]' > "${LOGDIR}/themes.json"
[[ -f "${LOGDIR}/theme_active.json" ]] || echo '[]' > "${LOGDIR}/theme_active.json"
[[ -f "${LOGDIR}/plugins.json" ]] || echo '[]' > "${LOGDIR}/plugins.json"
[[ -f "${LOGDIR}/mu_plugins.json" ]] || echo '[]' > "${LOGDIR}/mu_plugins.json"
[[ -f "${LOGDIR}/admins.json" ]] || echo '[]' > "${LOGDIR}/admins.json"
[[ -f "${LOGDIR}/plugins_active.json" ]] || echo '[]' > "${LOGDIR}/plugins_active.json"
[[ -f "${LOGDIR}/counts.json" ]] || echo '{}' > "${LOGDIR}/counts.json"
[[ -f "${LOGDIR}/plugins_trees.json" ]] || echo '{}' > "${LOGDIR}/plugins_trees.json"

THEME_ACTIVE_JSON="$(jq 'if type=="array" and length>0 then .[0] else null end' "${LOGDIR}/theme_active.json" 2>/dev/null || echo 'null')"

if [[ ${have_jq} -eq 1 ]]; then
  jq -n \
    --argjson run_id "${RUN_ID}" \
    --arg timestamp "${TS_NOW}" \
    --argfile site "${LOGDIR}/site_info.json" \
    --argfile themes_all "${LOGDIR}/themes.json" \
    --argfile plugins_std "${LOGDIR}/plugins.json" \
    --argfile plugins_mu "${LOGDIR}/mu_plugins.json" \
    --argfile admins "${LOGDIR}/admins.json" \
    --argfile plugs_active "${LOGDIR}/plugins_active.json" \
    --argfile counts "${LOGDIR}/counts.json" \
    --argfile trees "${LOGDIR}/plugins_trees.json" \
    --arg server_user "${SERVER_USER}" \
    --arg server_uname "${SERVER_UNAME}" \
    --arg server_datetime "${SERVER_DT}" \
    --arg server_cwd "${SERVER_CWD}" \
    --arg ssot_path ".wtp/ssot.yml" \
    --arg ssot_sha1 "${SSOT_SHA1}" \
    --arg ssot_b64 "${SSOT_B64}" \
    --arg theme_active "${THEME_ACTIVE_JSON}" \
    '{
      run_id: $run_id,
      timestamp: $timestamp,
      site: $site,
      server: {
        user: $server_user,
        uname: $server_uname,
        datetime: $server_datetime,
        cwd: $server_cwd
      },
      theme: {
        active: (try ($theme_active | fromjson) catch null),
        all: $themes_all
      },
      plugins: {
        standard: $plugins_std,
        must_use: $plugins_mu,
        trees: $trees
      },
      admins: $admins,
      summary: {
        plugins_active: $plugs_active,
        counts: $counts,
        errors: ( if (input_filename|tostring) then [] else [] end ) # placeholder (nadpisz poniżej)
      },
      wtp: {
        ssot_path: $ssot_path,
        ssot_sha1: $ssot_sha1,
        ssot_b64: $ssot_b64
      }
    }' > "${LOGDIR}/snapshot.json" || note_err "Build snapshot.json failed."

  # Wczytaj errors.txt -> summary.errors
  if [[ -s "${ERR_FILE}" ]]; then
    ERR_JSON="$(jq -Rs 'split("\n") | map(select(length>0))' "${ERR_FILE}" 2>/dev/null || echo '[]')"
  else
    ERR_JSON="[]"
  fi
  # wstrzyknij errors
  tmp_snap="$(mktemp)"
  jq --argjson errs "${ERR_JSON}" '.summary.errors = $errs' "${LOGDIR}/snapshot.json" > "${tmp_snap}" && mv "${tmp_snap}" "${LOGDIR}/snapshot.json" || true

else
  # Minimal fallback bez jq – pojedyncza linia JSON (wystarczy, by 03 nie padł)
  cat > "${LOGDIR}/snapshot.json" <<EOF
{"run_id": ${RUN_ID}, "timestamp": "${TS_NOW}", "site": $(cat "${LOGDIR}/site_info.json"), "server": {"user":"${SERVER_USER}","uname":"${SERVER_UNAME}","datetime":"${SERVER_DT}","cwd":"${SERVER_CWD}"}, "theme": {"active": null, "all": []}, "plugins": {"standard": [], "must_use": [], "trees": {}}, "admins": [], "summary": {"plugins_active": [], "counts": {"themes_total": 0, "plugins_total": 0, "plugins_active": 0, "plugins_mu": 0, "admins": 0}, "errors": ["jq missing – produced minimal snapshot"]}, "wtp": {"ssot_path": ".wtp/ssot.yml", "ssot_sha1": "${SSOT_SHA1}", "ssot_b64": "${SSOT_B64}"}}
EOF
fi

# Koniec – sukces niezależnie od niekrytycznych błędów
exit 0
