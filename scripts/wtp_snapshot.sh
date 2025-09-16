#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${RUN_ID:?RUN_ID is required}"

LOGDIR="${TARGET}/.wtp/state/ci_logs/snapshot"
mkdir -p "${LOGDIR}"

ERR_FILE="${LOGDIR}/errors.txt"
: > "${ERR_FILE}"

note_err() { echo "$1" | tee -a "${ERR_FILE}" 1>&2 || true; }
run_wp() { php ./wp "$@" --path="${TARGET}"; }

# ======================== A) SITE / CORE ========================
SITE_URL="$(run_wp option get siteurl 2>/dev/null || true)"
SITE_HOME="$(run_wp option get home 2>/dev/null || true)"
WP_VER="$(run_wp core version 2>/dev/null || true)"
TABLE_PREFIX="$(grep -E "^\s*\\\$table_prefix\s*=" "${TARGET}/wp-config.php" 2>/dev/null \
  | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/" | head -n1 || echo "wp_")"
WPLANG="$(run_wp option get WPLANG 2>/dev/null || true)"
TZ_STR="$(run_wp option get timezone_string 2>/dev/null || true)"; [[ -z "${TZ_STR}" || "${TZ_STR}" == "false" ]] && TZ_STR="$(run_wp option get gmt_offset 2>/dev/null || true)"
PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
php -v > "${LOGDIR}/php_info.txt" 2>&1 || note_err "php -v failed."

# site_info.json – przez PHP (zero jq)
env \
  SITE_URL="${SITE_URL}" SITE_HOME="${SITE_HOME}" WP_VER="${WP_VER}" \
  TABLE_PREFIX="${TABLE_PREFIX}" WPLANG="${WPLANG}" TZ_STR="${TZ_STR}" PHP_VERSION="${PHP_VERSION}" \
  php -r 'echo json_encode([
    "url"=>getenv("SITE_URL"),
    "home"=>getenv("SITE_HOME"),
    "wp_version"=>getenv("WP_VER"),
    "table_prefix"=>getenv("TABLE_PREFIX"),
    "language"=>getenv("WPLANG"),
    "timezone"=>getenv("TZ_STR"),
    "php_version"=>getenv("PHP_VERSION")
  ], JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);' \
  > "${LOGDIR}/site_info.json" || note_err "Failed to build site_info.json."

# ======================== B) THEMES ========================
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/theme_active.json"
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/themes.json"

ACTIVE_THEME="$(php -r '$f=getenv("F"); if(!file_exists($f))exit; $a=json_decode(file_get_contents($f),true); if(is_array($a)&&isset($a[0]["stylesheet"])) echo $a[0]["stylesheet"];' F="${LOGDIR}/theme_active.json" 2>/dev/null || true)"
THEME_FILES=0; THEME_SHA1=""
if [[ -n "$ACTIVE_THEME" && -d "$TARGET/wp-content/themes/$ACTIVE_THEME" ]]; then
  mkdir -p "${LOGDIR}/theme"
  (cd "$TARGET/wp-content/themes/$ACTIVE_THEME" && find . -type f | sort) > "${LOGDIR}/theme/tree.txt" || true
  (cd "$TARGET/wp-content/themes/$ACTIVE_THEME" && find . -type f -exec sha1sum {} \; | sort) > "${LOGDIR}/theme/hashes.sha1" || true
  [[ -s "${LOGDIR}/theme/tree.txt" ]] && THEME_FILES=$(wc -l < "${LOGDIR}/theme/tree.txt" || echo 0)
  [[ -s "${LOGDIR}/theme/hashes.sha1" ]] && THEME_SHA1=$(sha1sum "${LOGDIR}/theme/hashes.sha1" | awk '{print $1}')
else
  note_err "active theme directory not found"
fi

# ======================== C) PLUGINS (standard) ========================
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/plugins.json"
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || echo '' > "${LOGDIR}/plugins.csv"
run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/plugins_active.json"
php -r '$p=getenv("P"); if(file_exists($p)){ $a=json_decode(file_get_contents($p),true)?:[]; foreach($a as $s) echo $s,PHP_EOL; }' P="${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" 2>/dev/null || true

# fingerprinty pluginów
mkdir -p "${LOGDIR}/plugins"
php -r '$p=getenv("P"); if(!file_exists($p))exit; $arr=json_decode(file_get_contents($p),true)?:[]; foreach($arr as $r){ if(isset($r["name"])) echo $r["name"],PHP_EOL; }' P="${LOGDIR}/plugins.json" > "${LOGDIR}/plugins_slugs.txt" 2>/dev/null || true
: > "${LOGDIR}/plugins_trees.tsv"   # slug \t files \t sha1
while IFS= read -r slug; do
  [[ -z "$slug" ]] && continue
  PDIR="${TARGET}/wp-content/plugins/$slug"
  if [[ -d "$PDIR" ]]; then
    mkdir -p "${LOGDIR}/plugins/$slug"
    (cd "$PDIR" && find . -type f | sort) > "${LOGDIR}/plugins/$slug/tree.txt" || true
    (cd "$PDIR" && find . -type f -exec sha1sum {} \; | sort) > "${LOGDIR}/plugins/$slug/hashes.sha1" || true
    COUNT=0; [[ -s "${LOGDIR}/plugins/$slug/tree.txt" ]] && COUNT=$(wc -l < "${LOGDIR}/plugins/$slug/tree.txt" || echo 0)
    SHA="";  [[ -s "${LOGDIR}/plugins/$slug/hashes.sha1" ]] && SHA=$(sha1sum "${LOGDIR}/plugins/$slug/hashes.sha1" | awk '{print $1}')
    echo -e "${slug}\t${COUNT}\t${SHA}" >> "${LOGDIR}/plugins_trees.tsv"
  fi
done < "${LOGDIR}/plugins_slugs.txt"

# ======================== D) MU-plugins ========================
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/mu_plugins.json"
MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins"
[[ -d "${MU_DIR}" ]] && ls -la "${MU_DIR}" > "${LOGDIR}/mu-plugins/_ls.txt" || echo "mu-plugins dir not found" > "${LOGDIR}/mu-plugins/_ls.txt"
[[ -d "${MU_DIR}" ]] && find "${MU_DIR}" -type f -exec sha1sum {} \; | sort > "${LOGDIR}/mu-plugins/_hashes.txt" || : > "${LOGDIR}/mu-plugins/_hashes.txt"

# nagłówki
if [[ -d "${MU_DIR}" ]]; then
  for f in "${MU_DIR}"/*.php; do
    [[ -f "$f" ]] || continue
    head -n 60 "$f" | grep -E "^\s*\*\s*Plugin Name:" -m1 > "${LOGDIR}/mu-plugins/$(basename "$f").header.txt" || true
  done
fi

# mu fingerprint + off
: > "${LOGDIR}/mu_trees.tsv"
: > "${LOGDIR}/mu_off.txt"
if [[ -d "${MU_DIR}" ]]; then
  for off in "${MU_DIR}"/*.off; do
    [[ -f "$off" ]] && echo "$(basename "$off")" >> "${LOGDIR}/mu_off.txt"
  done
  for mu in "${MU_DIR}"/*.php; do
    [[ -f "$mu" ]] || continue
    slug="$(basename "$mu" .php)"
    SHA="$(sha1sum "$mu" | awk '{print $1}')"
    echo -e "${slug}\t1\t${SHA}" >> "${LOGDIR}/mu_trees.tsv"
  done
else
  note_err "wp-content/mu-plugins not found."
fi

# ======================== E) Users ========================
run_wp user list --role=administrator --field=user_login --format=json > "${LOGDIR}/admins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/admins.json"

# ======================== F) SSOT ========================
SSOT_PATH="${TARGET}/.wtp/ssot.yml"
SSOT_SHA1=""; SSOT_B64=""
if [[ -f "${SSOT_PATH}" ]]; then
  SSOT_SHA1="$(sha1sum "${SSOT_PATH}" | awk '{print $1}' 2>/dev/null || true)"
  SSOT_B64="$(base64 -w0 "${SSOT_PATH}" 2>/dev/null || base64 "${SSOT_PATH}" | tr -d '\n' || true)"
  cp "${SSOT_PATH}" "${LOGDIR}/ssot.yml" 2>/dev/null || true
  echo "${SSOT_SHA1}" > "${LOGDIR}/ssot.sha1" 2>/dev/null || true
else
  note_err "SSOT file .wtp/ssot.yml not found."
fi

# ======================== G) Server info ========================
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

# ======================== H) COUNTS (PHP) ========================
php -r '
  $L="'${LOGDIR}'";
  $r=function($f,$d){ return file_exists($f) ? (json_decode(file_get_contents($f),true)?:$d) : $d; };
  $counts=[
    "themes_total"=>count($r("$L/themes.json",[])),
    "plugins_total"=>count($r("$L/plugins.json",[])),
    "plugins_active"=>count($r("$L/plugins_active.json",[])),
    "plugins_mu"=>count($r("$L/mu_plugins.json",[])),
    "admins"=>count($r("$L/admins.json",[])),
  ];
  echo json_encode($counts, JSON_UNESCAPED_SLASHES|JSON_PRETTY_PRINT);
' > "${LOGDIR}/counts.json" 2>/dev/null || echo '{}' > "${LOGDIR}/counts.json"

# ======================== I) WEB CAPTURE (HTML + opcjonalnie PNG) ========================
SC_DIR="${LOGDIR}/screens"
mkdir -p "${SC_DIR}"

# Przygotuj listę URL (na start: siteurl, /wp-admin, /kontakt)
URLS=()
[[ -n "${SITE_URL}" ]] && URLS+=("${SITE_URL}")
[[ -n "${SITE_URL}" ]] && URLS+=("${SITE_URL%/}/wp-admin")
[[ -n "${SITE_URL}" ]] && URLS+=("${SITE_URL%/}/kontakt")

HAS_WKHTML=0
if command -v wkhtmltoimage >/dev/null 2>&1; then
  HAS_WKHTML=1
else
  note_err "wkhtmltoimage not found – screenshots PNG skipped (HTML saved)."
fi

for U in "${URLS[@]}"; do
  # Bezpieczna nazwa pliku: host_path
  SAFE="$(echo "${U}" | sed -E 's#^https?://##; s#[^a-zA-Z0-9._-]+#_#g')"
  OUT="${SC_DIR}/${SAFE}"
  # Pobierz HTML + nagłówki + HTTP code
  CODE="$(curl -sS -k -L -m 25 -A "WTP-CI/1.0" -D "${OUT}.headers" -o "${OUT}.html" -w "%{http_code}" "${U}" || echo "000")"
  echo -n "${CODE}" > "${OUT}.code"
  # Zrób PNG jeśli mamy wkhtmltoimage
  if [[ "${HAS_WKHTML}" -eq 1 ]]; then
    wkhtmltoimage --width 1366 --quality 70 "${U}" "${OUT}.png" >/dev/null 2>&1 || note_err "PNG capture failed for ${U}"
  fi
done

# Zbuduj index JSON dla capture (PHP)
php -r '
  $d=getenv("SC_DIR");
  $out=[];
  if (is_dir($d)) {
    foreach (glob($d."/*.html") as $html) {
      $base=preg_replace("/\.html$/","",$html);
      $code=@file_exists($base.".code")?trim(@file_get_contents($base.".code")):"";
      $hdr =@file_exists($base.".headers")?basename($base.".headers"):"";
      $png =@file_exists($base.".png")?basename($base.".png"):"";
      $url =preg_replace("#^.*?/screens/#","",$base);
      $out[]=[
        "safe_id"=>$url,
        "code"=>$code,
        "html"=>basename($html),
        "headers"=>$hdr ?: null,
        "png"=>$png ?: null
      ];
    }
  }
  echo json_encode($out, JSON_UNESCAPED_SLASHES|JSON_PRETTY_PRINT);
' > "${SC_DIR}/screens_index.json" 2>/dev/null || echo '[]' > "${SC_DIR}/screens_index.json"

# ======================== J) Final snapshot (PHP) ========================
TS_NOW="$(date -Is)"

env \
  LOGDIR="${LOGDIR}" RUN_ID="${RUN_ID}" TS_NOW="${TS_NOW}" \
  SERVER_USER="${SERVER_USER}" SERVER_UNAME="${SERVER_UNAME}" SERVER_DT="${SERVER_DT}" SERVER_CWD="${SERVER_CWD}" \
  THEME_FILES="${THEME_FILES}" THEME_SHA1="${THEME_SHA1}" \
  SSOT_SHA1="${SSOT_SHA1}" SSOT_B64="${SSOT_B64}" \
  php -r '
    $L=getenv("LOGDIR");
    $read=function($p,$d){ return file_exists($p)?(json_decode(file_get_contents($p),true)?:$d):$d; };
    $mkTrees=function($tsv){
      $m=[]; if(!file_exists($tsv)) return $m;
      $h=fopen($tsv,"r"); if(!$h) return $m;
      while(($line=fgets($h))!==false){
        $line=rtrim($line,"\r\n"); if($line==="") continue;
        [$slug,$files,$sha]=array_pad(explode("\t",$line),3,"");
        $m[$slug]=["files"=>(int)$files,"sha1"=>$sha];
      } fclose($h); return $m;
    };
    $mu_off=[]; $off="$L/mu_off.txt"; if(file_exists($off)){ foreach(explode("\n",trim(file_get_contents($off))) as $x){ if($x!=="") $mu_off[]=$x; } }
    $errors=[]; $ef="$L/errors.txt"; if(file_exists($ef)){ foreach(explode("\n",file_get_contents($ef)) as $e){ $e=trim($e); if($e!=="") $errors[]=$e; } }
    $capture=$read("$L/screens/screens_index.json",[]);
    $snap=[
      "run_id"=>(int)getenv("RUN_ID"),
      "timestamp"=>getenv("TS_NOW"),
      "site"=>$read("$L/site_info.json",[]),
      "server"=>[
        "user"=>getenv("SERVER_USER"), "uname"=>getenv("SERVER_UNAME"),
        "datetime"=>getenv("SERVER_DT"), "cwd"=>getenv("SERVER_CWD")
      ],
      "theme"=>[
        "active"=>$read("$L/theme_active.json",[]),
        "all"=>$read("$L/themes.json",[]),
        "tree"=>["files"=>(int)getenv("THEME_FILES"), "sha1"=>getenv("THEME_SHA1")]
      ],
      "plugins"=>[
        "standard"=>$read("$L/plugins.json",[]),
        "must_use"=>$read("$L/mu_plugins.json",[]),
        "trees"=>$mkTrees("$L/plugins_trees.tsv"),
        "mu_trees"=>$mkTrees("$L/mu_trees.tsv"),
        "mu_off"=>$mu_off
      ],
      "admins"=>$read("$L/admins.json",[]),
      "summary"=>[
        "plugins_active"=>$read("$L/plugins_active.json",[]),
        "counts"=>$read("$L/counts.json",[]),
        "errors"=>$errors
      ],
      "wtp"=>[
        "ssot_path"=>".wtp/ssot.yml",
        "ssot_sha1"=>getenv("SSOT_SHA1")?: "",
        "ssot_b64"=>getenv("SSOT_B64")?: ""
      ],
      "web"=>[
        "capture"=>$capture
      ]
    ];
    echo json_encode($snap, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);
  ' > "${LOGDIR}/snapshot.json" 2>/dev/null || {
    # Minimalny awaryjny snapshot (gdyby PHP agregacja się wywaliła)
    cat > "${LOGDIR}/snapshot.json" <<EOF
{
  "run_id": ${RUN_ID},
  "timestamp": "${TS_NOW}",
  "site": $(cat "${LOGDIR}/site_info.json" 2>/dev/null || echo "{}"),
  "server": { "user": "${SERVER_USER}", "uname": "${SERVER_UNAME}", "datetime": "${SERVER_DT}", "cwd": "${SERVER_CWD}" },
  "theme": { "active": [], "all": [], "tree": { "files": ${THEME_FILES}, "sha1": "${THEME_SHA1}" } },
  "plugins": { "standard": [], "must_use": [], "trees": {}, "mu_trees": {}, "mu_off": [] },
  "admins": [],
  "summary": { "plugins_active": [], "counts": {}, "errors": ["fallback snapshot"] },
  "wtp": { "ssot_path": ".wtp/ssot.yml", "ssot_sha1": "${SSOT_SHA1}", "ssot_b64": "${SSOT_B64}" },
  "web": { "capture": [] }
}
EOF
  }

exit 0
