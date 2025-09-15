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

# Build site_info.json via PHP (instead of jq)
php -r '
  $info = [
    "url" => getenv("SITE_URL"),
    "home" => getenv("SITE_HOME"),
    "wp_version" => getenv("WP_VER"),
    "table_prefix" => getenv("TABLE_PREFIX"),
    "language" => getenv("WPLANG"),
    "timezone" => getenv("TZ_STR"),
    "php_version" => getenv("PHP_VERSION"),
  ];
  echo json_encode($info, JSON_PRETTY_PRINT);
' > "${LOGDIR}/site_info.json" || note_err "Failed to build site_info.json."

# ---------- B) Theme(s) ----------
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || note_err "wp theme list --status=active failed."
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || note_err "wp theme list --format=json failed."

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
  note_err "active theme directory not found"
fi

# ---------- C) Plugins (standard) ----------
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=json failed."
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=csv failed."

mkdir -p "${LOGDIR}/plugins"
for slug in $(jq -r '.[].name' "${LOGDIR}/plugins.json" 2>/dev/null || echo ""); do
  PDIR="${TARGET}/wp-content/plugins/$slug"
  if [[ -d "$PDIR" ]]; then
    mkdir -p "${LOGDIR}/plugins/$slug"
    (cd "$PDIR" && find . -type f | sort) > "${LOGDIR}/plugins/$slug/tree.txt"
    (cd "$PDIR" && find . -type f -exec sha1sum {} \; | sort) > "${LOGDIR}/plugins/$slug/hashes.sha1"
  fi
done

# ---------- D) MU-plugins ----------
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --status=must-use failed."

MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"
if [[ -d "${MU_DIR}" ]]; then
  ls -la "${MU_DIR}" > "${LOGDIR}/mu-plugins/_ls.txt"
  find "${MU_DIR}" -type f -exec sha1sum {} \; | sort > "${LOGDIR}/mu-plugins/_hashes.txt"
  for f in "${MU_DIR}"/*.php; do
    [[ -f "$f" ]] || continue
    head -n 50 "$f" | grep -E "^\s*\*\s*Plugin Name:" -m1 > "${LOGDIR}/mu-plugins/$(basename "$f").header.txt" || true
  done
  MU_OFF=$(ls "${MU_DIR}"/*.off 2>/dev/null || true)
else
  note_err "wp-content/mu-plugins not found."
fi

# ---------- E) Users (admini) ----------
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || note_err "wp user list --role=administrator failed."

# ---------- F) WTP / SSOT ----------
SSOT_PATH_REL=".wtp/ssot.yml"
SSOT_PATH="${TARGET}/${SSOT_PATH_REL}"
SSOT_SHA1=""
SSOT_B64=""
if [[ -f "${SSOT_PATH}" ]]; then
  cp "${SSOT_PATH}" "${LOGDIR}/ssot.yml" || true
  SSOT_SHA1="$(sha1sum "${SSOT_PATH}" | awk '{print $1}' 2>/dev/null || true)"
  echo "${SSOT_SHA1}" > "${LOGDIR}/ssot.sha1" || true
  SSOT_B64="$(base64 -w0 "${SSOT_PATH}" 2>/dev/null || base64 "${SSOT_PATH}" | tr -d '\n' || true)"
else
  note_err "SSOT file ${SSOT_PATH_REL} not found."
fi

# ---------- G) Server info ----------
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

# ---------- H) Summary ----------
run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" || echo "[]" > "${LOGDIR}/plugins_active.json"
jq -r '.[]' "${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" || true

THEMES_TOTAL=$(jq 'length' "${LOGDIR}/themes.json" 2>/dev/null || echo 0)
PLUGINS_TOTAL=$(jq 'length' "${LOGDIR}/plugins.json" 2>/dev/null || echo 0)
PLUGINS_ACTIVE_CNT=$(jq 'length' "${LOGDIR}/plugins_active.json" 2>/dev/null || echo 0)
PLUGINS_MU_CNT=$(jq 'length' "${LOGDIR}/mu_plugins.json" 2>/dev/null || echo 0)
ADMINS_CNT=$(jq 'length' "${LOGDIR}/admins.json" 2>/dev/null || echo 0)

php -r '
  $counts = [
    "themes_total" => (int)getenv("THEMES_TOTAL"),
    "plugins_total" => (int)getenv("PLUGINS_TOTAL"),
    "plugins_active" => (int)getenv("PLUGINS_ACTIVE_CNT"),
    "plugins_mu" => (int)getenv("PLUGINS_MU_CNT"),
    "admins" => (int)getenv("ADMINS_CNT"),
  ];
  echo json_encode($counts, JSON_PRETTY_PRINT);
' > "${LOGDIR}/counts.json"

if [[ -s "${ERR_FILE}" ]]; then
  jq -Rs 'split("\n") | map(select(length>0))' "${ERR_FILE}" > "${LOGDIR}/errors.json" 2>/dev/null || echo '[]' > "${LOGDIR}/errors.json"
else
  echo '[]' > "${LOGDIR}/errors.json"
fi

# ---------- Final snapshot ----------
TS_NOW="$(date -Is)"

php -r '
  $snapshot = [
    "run_id" => (int)getenv("RUN_ID"),
    "timestamp" => getenv("TS_NOW"),
    "site" => json_decode(file_get_contents(getenv("LOGDIR")."/site_info.json"), true),
    "server" => [
      "user" => getenv("SERVER_USER"),
      "uname" => getenv("SERVER_UNAME"),
      "datetime" => getenv("SERVER_DT"),
      "cwd" => getenv("SERVER_CWD")
    ],
    "theme" => [
      "active" => json_decode(file_get_contents(getenv("LOGDIR")."/theme_active.json"), true),
      "all" => json_decode(file_get_contents(getenv("LOGDIR")."/themes.json"), true),
      "tree" => ["files" => (int)getenv("THEME_FILES"), "sha1" => getenv("THEME_SHA1")]
    ],
    "plugins" => [
      "standard" => json_decode(file_get_contents(getenv("LOGDIR")."/plugins.json"), true),
      "must_use" => json_decode(file_get_contents(getenv("LOGDIR")."/mu_plugins.json"), true)
    ],
    "admins" => json_decode(file_get_contents(getenv("LOGDIR")."/admins.json"), true),
    "summary" => [
      "plugins_active" => json_decode(file_get_contents(getenv("LOGDIR")."/plugins_active.json"), true),
      "counts" => json_decode(file_get_contents(getenv("LOGDIR")."/counts.json"), true),
      "errors" => json_decode(file_get_contents(getenv("LOGDIR")."/errors.json"), true)
    ],
    "wtp" => [
      "ssot_path" => ".wtp/ssot.yml",
      "ssot_sha1" => getenv("SSOT_SHA1"),
      "ssot_b64" => getenv("SSOT_B64")
    ]
  ];
  echo json_encode($snapshot, JSON_PRETTY_PRINT);
' > "${LOGDIR}/snapshot.json" || note_err "Build snapshot.json failed."

exit 0
