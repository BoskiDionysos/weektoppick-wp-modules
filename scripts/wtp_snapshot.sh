#!/usr/bin/env bash
# scripts/wtp_snapshot.sh (bez jq na serwerze)
# Zbiera pełny stan WP i odkłada logi + snapshot.json na serwerze.
# WYMAGA zmiennych środowiskowych:
#   TARGET  – katalog WP na serwerze (np. /home/.../public_html)
#   RUN_ID  – numer runu GitHub (przekazuje go workflow)

set -euo pipefail

# --- Weryfikacja wejścia ---
: "${TARGET:?TARGET is required (path to WP root)}"
: "${RUN_ID:?RUN_ID is required (github run id)}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
mkdir -p "${LOGDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

note_err() {
  echo "$1" | tee -a "${ERR_FILE}" 1>&2 || true
}

run_wp() {
  # zawsze: php ./wp ... --path="${TARGET}"
  php ./wp "$@" --path="${TARGET}"
}

# ========== A) SITE / CORE ==========
SITE_URL="$(run_wp option get siteurl 2>/dev/null || true)"
SITE_HOME="$(run_wp option get home 2>/dev/null || true)"
WP_VER="$(run_wp core version 2>/dev/null || true)"

# Prefix z wp-config.php (odporne)
TABLE_PREFIX="$(grep -E "^\s*\\\$table_prefix\s*=" "${TARGET}/wp-config.php" 2>/dev/null \
  | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | head -n1 || echo "wp_")"

WPLANG="$(run_wp option get WPLANG 2>/dev/null || true)"
TZ_STR="$(run_wp option get timezone_string 2>/dev/null || run_wp option get gmt_offset 2>/dev/null || true)"

PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
php -v > "${LOGDIR}/php_info.txt" 2>&1 || note_err "php -v failed."

# site_info.json – bez jq (printf)
{
  printf '{\n'
  printf '  "url": "%s",\n'        "${SITE_URL}"
  printf '  "home": "%s",\n'       "${SITE_HOME}"
  printf '  "wp_version": "%s",\n' "${WP_VER}"
  printf '  "table_prefix": "%s",\n' "${TABLE_PREFIX}"
  printf '  "language": "%s",\n'   "${WPLANG}"
  printf '  "timezone": "%s",\n'   "${TZ_STR}"
  printf '  "php_version": "%s"\n' "${PHP_VERSION}"
  printf '}\n'
} > "${LOGDIR}/site_info.json" || note_err "site_info.json write failed."

# ========== B) THEMES ==========
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || note_err "wp theme list --status=active failed."
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || note_err "wp theme list --format=json failed."

# Aktywny motyw (czytamy JSON przez mini-PHP)
ACTIVE_THEME_SLUG="$(php -r '
  $p = getenv("P"); if(!is_readable($p)){echo "";exit;}
  $j = json_decode(file_get_contents($p), true);
  if (is_array($j) && count($j)>0 && isset($j[0]["stylesheet"])) echo $j[0]["stylesheet"];
' P="${LOGDIR}/theme_active.json" 2>/dev/null || true)"

# Drzewo i hashe aktywnego motywu
THEMES_DIR="${TARGET}/wp-content/themes"
if [[ -n "${ACTIVE_THEME_SLUG}" && -d "${THEMES_DIR}/${ACTIVE_THEME_SLUG}" ]]; then
  OUTDIR="${LOGDIR}/theme/${ACTIVE_THEME_SLUG}"
  mkdir -p "${OUTDIR}"
  find "${THEMES_DIR}/${ACTIVE_THEME_SLUG}" -type f -print0 | sort -z | tr '\0' '\n' > "${OUTDIR}/tree.txt" 2>>"${ERR_FILE}" || true
  { find "${THEMES_DIR}/${ACTIVE_THEME_SLUG}" -type f -print0 | sort -z | xargs -0 sha1sum; } > "${OUTDIR}/hashes.sha1" 2>>"${ERR_FILE}" || true
else
  mkdir -p "${LOGDIR}/theme"
  echo "Active theme directory not found: ${ACTIVE_THEME_SLUG}" > "${LOGDIR}/theme/_warn.txt" || true
fi

# ========== C) PLUGINS (STANDARD) ==========
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=json failed."
run_wp plugin list --format=csv  > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || note_err "wp plugin list --format=csv failed."

# Per-plugin: drzewo + hashe
PLUG_DIR="${TARGET}/wp-content/plugins"
mkdir -p "${LOGDIR}/plugins"
if [[ -d "${PLUG_DIR}" ]]; then
  # spróbuj slugi z JSON (mini-PHP); fallback: katalogi
  if [[ -s "${LOGDIR}/plugins.json" ]]; then
    php -r '
      $p=getenv("P"); $j=@json_decode(@file_get_contents($p),true);
      if(is_array($j)) foreach($j as $it){ if(isset($it["name"])) echo $it["name"],"\n"; }
    ' P="${LOGDIR}/plugins.json" | sort -u > "${LOGDIR}/_slugs.txt" 2>/dev/null || true
  fi
  if [[ ! -s "${LOGDIR}/_slugs.txt" ]]; then
    find "${PLUG_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort > "${LOGDIR}/_slugs.txt" || true
  fi

  while IFS= read -r slug; do
    [[ -n "$slug" && -d "${PLUG_DIR}/${slug}" ]] || continue
    OUTDIR="${LOGDIR}/plugins/${slug}"
    mkdir -p "${OUTDIR}"
    find "${PLUG_DIR}/${slug}" -type f -print0 | sort -z | tr '\0' '\n' > "${OUTDIR}/tree.txt" 2>>"${ERR_FILE}" || true
    { find "${PLUG_DIR}/${slug}" -type f -print0 | sort -z | xargs -0 sha1sum; } > "${OUTDIR}/hashes.sha1" 2>>"${ERR_FILE}" || true
  done < "${LOGDIR}/_slugs.txt"
fi

# ========== D) MU-PLUGINS ==========
MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"

if [[ -d "${MU_DIR}" ]]; then
  ls -la "${MU_DIR}" > "${LOGDIR}/mu-plugins/_ls.txt" 2>>"${ERR_FILE}" || note_err "ls mu-plugins failed."
  find "${MU_DIR}" -type f -print0 | sort -z | xargs -0 sha1sum > "${LOGDIR}/mu-plugins/_hashes.txt" 2>>"${ERR_FILE}" || true
  # nagłówki (Plugin Name) z plików PHP
  find "${MU_DIR}" -maxdepth 1 -type f -name "*.php" -print0 | \
    while IFS= read -r -d '' f; do
      head -n 50 "$f" | grep -E "^\s*\*\s*Plugin Name:" -m1 > "${LOGDIR}/mu-plugins/$(basename "$f").header.txt" 2>>"${ERR_FILE}" || true
    done

  # per-MU: tree + hashes (pojedynczy plik)
  find "${MU_DIR}" -maxdepth 1 -type f -name "*.php" -print0 | \
    while IFS= read -r -d '' f; do
      slug="$(basename "$f" .php)"
      OUTDIR="${LOGDIR}/mu-plugins/${slug}"
      mkdir -p "${OUTDIR}"
      printf '%s\n' "${f}" > "${OUTDIR}/tree.txt" 2>>"${ERR_FILE}" || true
      sha1sum "${f}" > "${OUTDIR}/hashes.sha1" 2>>"${ERR_FILE}" || true
    done

  # MU OFF (pliki *.php.off)
  find "${MU_DIR}" -maxdepth 1 -type f -name "*.php.off" -printf '%f\n' \
    | sort > "${LOGDIR}/mu-plugins/_off.txt" 2>>"${ERR_FILE}" || true
else
  echo "mu-plugins directory not found." > "${LOGDIR}/mu-plugins/_ls.txt"
  : > "${LOGDIR}/mu-plugins/_hashes.txt"
  : > "${LOGDIR}/mu-plugins/_off.txt"
  note_err "wp-content/mu-plugins not found."
fi

run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || note_err "wp plugin list --status=must-use failed."

# ========== E) USERS (ADMINI) ==========
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || note_err "wp user list admins failed."

# ========== F) WTP / SSOT ==========
SSOT_PATH="${TARGET}/.wtp/ssot.yml"
SSOT_SHA1=""
SSOT_B64=""
if [[ -f "${SSOT_PATH}" ]]; then
  cp "${SSOT_PATH}" "${LOGDIR}/ssot.yml" 2>>"${ERR_FILE}" || note_err "Copy ssot.yml failed."
  SSOT_SHA1="$(sha1sum "${SSOT_PATH}" | awk '{print $1}')" || true
  echo "${SSOT_SHA1}" > "${LOGDIR}/ssot.sha1" || true
  SSOT_B64="$(base64 -w0 "${SSOT_PATH}" 2>/dev/null || base64 "${SSOT_PATH}" | tr -d '\n')" || true
else
  note_err "SSOT file .wtp/ssot.yml not found."
fi

# ========== G) SERVER INFO ==========
SERVER_USER="$(whoami 2>/dev/null || true)"
SERVER_UNAME="$(uname -a 2>/dev/null || true)"
SERVER_DT="$(date -Is 2>/dev/null || true)"
SERVER_CWD="$(cd "${TARGET}" && pwd 2>/dev/null || true)"

{
  echo "user: ${SERVER_USER}"
  echo "uname: ${SERVER_UNAME}"
  echo "datetime: ${SERVER_DT}"
  echo "cwd: ${SERVER_CWD}"
} > "${LOGDIR}/server_info.txt" 2>>"${ERR_FILE}" || note_err "server_info.txt write failed."

# ========== H) Active plugins (summary helpers) ==========
run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" 2>>"${ERR_FILE}" || note_err "wp plugin list active names failed."
if [[ -s "${LOGDIR}/plugins_active.json" ]]; then
  # szybka płaska lista do pliku .txt
  php -r '
    $p=getenv("P"); $j=@json_decode(@file_get_contents($p),true);
    if(is_array($j)) foreach($j as $n){ echo $n, "\n"; }
  ' P="${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" 2>>"${ERR_FILE}" || true
else
  : > "${LOGDIR}/plugins_active.txt"
fi

# ========== I) Build snapshot.json (PHP – bez jq) ==========
# Zbieramy wszystko i składamy snapshot.json, summary.txt i wpcli_summary.txt
cat > /tmp/wtp_build_snapshot.php <<'PHPBUILDER'
<?php
error_reporting(E_ALL);
$log = getenv('LOGDIR');
$run = getenv('RUN_ID');
$ts  = date('c');

function jr($p,$d){ return ($p && is_readable($p)) ? (json_decode(file_get_contents($p), true) ?? $d) : $d; }
function fr($p,$d=''){ return ($p && is_readable($p)) ? file_get_contents($p) : $d; }

$site   = jr("$log/site_info.json", new stdClass());
$themes = jr("$log/themes.json", []);
$tact   = jr("$log/theme_active.json", []);
$themeActive = (is_array($tact) && count($tact)>0) ? $tact[0] : null;

# theme tree/hash
$themeTree = [];
if (is_array($themeActive) && isset($themeActive['stylesheet'])) {
  $slug = $themeActive['stylesheet'];
  $tDir = "$log/theme/$slug";
  $files = 0; $sha = '';
  if (is_dir($tDir)) {
    $tree  = "$tDir/tree.txt";
    $hashf = "$tDir/hashes.sha1";
    $files = (is_readable($tree)) ? max(0, count(file($tree, FILE_IGNORE_NEW_LINES))) : 0;
    if (is_readable($hashf)) {
      $all = preg_replace('/\s+.*/','', file_get_contents($hashf));
      $all = preg_replace('/\s+/','', $all);
      $sha = substr(sha1($all), 0, 40);
    }
  }
  $themeTree = ['stylesheet'=>$slug, 'files'=>$files, 'sha1'=>$sha];
}

$pluginsStd    = jr("$log/plugins.json", []);
$pluginsMU     = jr("$log/mu_plugins.json", []);
$admins        = jr("$log/admins.json", []);
$pluginsActive = jr("$log/plugins_active.json", []);

# trees (standard plugins)
$trees = [];
$dir = "$log/plugins";
if (is_dir($dir)) {
  foreach (scandir($dir) as $slug) {
    if ($slug==='.'||$slug==='..') continue;
    $p = "$dir/$slug"; if(!is_dir($p)) continue;
    $tree  = "$p/tree.txt";
    $hashf = "$p/hashes.sha1";
    $files = (is_readable($tree)) ? max(0,count(file($tree, FILE_IGNORE_NEW_LINES))) : 0;
    $sha = '';
    if (is_readable($hashf)) {
      $all = preg_replace('/\s+.*/','',file_get_contents($hashf)); // tylko kolumna sumy
      $all = preg_replace('/\s+/','',$all);
      $sha = substr(sha1($all),0,40);
    }
    $trees[$slug] = ['files'=>$files,'sha1'=>$sha];
  }
}

# MU trees (pojedyncze pliki)
$muTrees = [];
$muDir = "$log/mu-plugins";
if (is_dir($muDir)) {
  foreach (scandir($muDir) as $slug) {
    if ($slug==='.'||$slug==='..') continue;
    $p = "$muDir/$slug";
    if (!is_dir($p)) continue;
    $tree  = "$p/tree.txt";
    $hashf = "$p/hashes.sha1";
    $files = (is_readable($tree)) ? max(0, count(file($tree, FILE_IGNORE_NEW_LINES))) : 0;
    $sha = '';
    if (is_readable($hashf)) {
      $all = preg_replace('/\s+.*/','', file_get_contents($hashf));
      $all = preg_replace('/\s+/','', $all);
      $sha = substr(sha1($all), 0, 40);
    }
    $muTrees[$slug] = ['files'=>$files,'sha1'=>$sha];
  }
}

# MU OFF (pliki .php.off)
$muOff = [];
$offList = "$log/mu-plugins/_off.txt";
if (is_readable($offList)) {
  $muOff = array_values(array_filter(array_map('trim', file($offList, FILE_IGNORE_NEW_LINES))));
}

# counts (standard != must-use)
$stdOnly = array_values(array_filter($pluginsStd, fn($p)=>is_array($p) && (($p['status']??'')!=='must-use')));
$counts = [
  'themes_total'   => is_array($themes)?count($themes):0,
  'plugins_total'  => count($stdOnly),
  'plugins_active' => is_array($pluginsActive)?count($pluginsActive):0,
  'plugins_mu'     => is_array($pluginsMU)?count($pluginsMU):0,
  'admins'         => is_array($admins)?count($admins):0
];

# errors
$errors = [];
$e="$log/errors.txt";
if (is_readable($e)) { $errors = array_values(array_filter(array_map('trim', file($e)))); }

# server
$srv=['user'=>'','uname'=>'','datetime'=>'','cwd'=>''];
$si=fr("$log/server_info.txt");
if($si){
  foreach(explode("\n",$si) as $ln){
    if(preg_match('/^([a-z]+):\s*(.*)$/i',trim($ln),$m)){ $srv[$m[1]]=$m[2]; }
  }
}

# ssot
$ssot_path='.wtp/ssot.yml';
$ssot_sha1=trim(fr("$log/ssot.sha1"));
$ssot_b64= is_readable("$log/ssot.yml") ? base64_encode(file_get_contents("$log/ssot.yml")) : '';

$out = [
  'run_id'=>(int)$run,
  'timestamp'=>$ts,
  'site'=>$site,
  'server'=>$srv,
  'theme'=>[
    'active'=>$themeActive,
    'all'=>$themes,
    'tree'=>$themeTree
  ],
  'plugins'=>[
    'standard'=>$pluginsStd,
    'must_use'=>$pluginsMU,
    'trees'=>$trees,
    'mu_trees'=>$muTrees,
    'mu_off'=>$muOff
  ],
  'admins'=>$admins,
  'summary'=>[
    'plugins_active'=>$pluginsActive,
    'counts'=>$counts,
    'errors'=>$errors
  ],
  'wtp'=>[
    'ssot_path'=>$ssot_path,
    'ssot_sha1'=>$ssot_sha1,
    'ssot_b64'=>$ssot_b64
  ]
];
file_put_contents("$log/snapshot.json", json_encode($out, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE));

# summary.txt (ludzki skrót)
$active = is_array($pluginsActive)? implode(',', $pluginsActive) : '';
$sum = "run_id: ".$run."\n".
       "timestamp: ".$ts."\n".
       "site.url: ".(($site['url']??'') ?: '')."\n".
       "wp/php: ".(($site['wp_version']??'') ?: '')." / ".(($site['php_version']??'') ?: '')."\n".
       "themes_total: ".$counts['themes_total']."\n".
       "plugins_total: ".$counts['plugins_total']."\n".
       "plugins_active: ".$counts['plugins_active']."\n".
       "plugins_mu: ".$counts['plugins_mu']."\n".
       "admins: ".$counts['admins']."\n".
       "active_theme: ".(($themeActive['stylesheet']??'') ?: '')."\n".
       "active_plugins: ".$active."\n";
file_put_contents("$log/summary.txt", $sum);

# wpcli_summary.txt (skrót WP-CLI)
$w = [];
$w[] = "SITE_URL: ".(($site['url']??'') ?: '');
$w[] = "WP_VERSION: ".(($site['wp_version']??'') ?: '');
$w[] = "PHP_VERSION: ".(($site['php_version']??'') ?: '');
$w[] = "ACTIVE_THEME: ".(($themeActive['stylesheet']??'') ?: '')." ".(($themeActive['version']??'') ?: '');
$w[] = "ADMINS_COUNT: ".$counts['admins'];
$w[] = "PLUGINS_TOTAL: ".$counts['plugins_total']."; ACTIVE: ".$counts['plugins_active']."; MU: ".$counts['plugins_mu'];
if ($active) $w[] = "ACTIVE_PLUGINS: ".$active;
file_put_contents("$log/wpcli_summary.txt", implode("\n",$w)."\n");
PHPBUILDER

LOGDIR="${LOGDIR}" RUN_ID="${RUN_ID}" php /tmp/wtp_build_snapshot.php 2>>"${ERR_FILE}" || note_err "snapshot.json build failed."
rm -f /tmp/wtp_build_snapshot.php || true

# --- Koniec ---
exit 0
