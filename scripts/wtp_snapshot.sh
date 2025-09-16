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

# site_info.json – PHP (zero jq)
env SITE_URL="${SITE_URL}" SITE_HOME="${SITE_HOME}" WP_VER="${WP_VER}" \
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

# ======================== B) THEMES (self-healing) ========================
run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/theme_active.json"
run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/themes.json"

ACTIVE_THEME="$(php -r '$f=getenv("F"); if(!file_exists($f))exit; $a=json_decode(file_get_contents($f),true); if(is_array($a)&&isset($a[0]["stylesheet"])) echo $a[0]["stylesheet"];' F="${LOGDIR}/theme_active.json" 2>/dev/null || true)"

ensure_theme_ready() {
  local slug="$1"
  # jeśli istnieje — OK
  if [[ -n "$slug" && -d "$TARGET/wp-content/themes/$slug" ]]; then
    echo "$slug"; return 0
  fi
  # preferuj nasz motyw jeśli jest
  for CAND in "wtp-core-theme" "wtp" "wtp-theme"; do
    if [[ -d "$TARGET/wp-content/themes/$CAND" ]]; then
      run_wp theme activate "$CAND" >/dev/null 2>&1 || note_err "cannot activate theme $CAND"
      echo "$CAND"; return 0
    fi
  done
  # pierwszy sensowny z listy (nie twenty*)
  local picked=""
  picked="$(php -r '
    $p=getenv("P"); $arr=file_exists($p)?(json_decode(file_get_contents($p), true)?:[]):[];
    foreach($arr as $t){ $s=$t["stylesheet"]??""; if($s==="" )continue; if(preg_match("#^(twenty|twentytwenty)#i",$s)) continue; echo $s; exit; }
  ' P="${LOGDIR}/themes.json" 2>/dev/null || true)"
  if [[ -n "$picked" && -d "$TARGET/wp-content/themes/$picked" ]]; then
    run_wp theme activate "$picked" >/dev/null 2>&1 || note_err "cannot activate theme $picked"
    echo "$picked"; return 0
  fi
  # ostatecznie pierwszy z listy
  picked="$(php -r '$p=getenv("P");$a=file_exists($p)?(json_decode(file_get_contents($p),true)?:[]):[]; if(isset($a[0]["stylesheet"])) echo $a[0]["stylesheet"];' P="${LOGDIR}/themes.json" 2>/dev/null || true)"
  if [[ -n "$picked" && -d "$TARGET/wp-content/themes/$picked" ]]; then
    run_wp theme activate "$picked" >/dev/null 2>&1 || note_err "cannot activate theme $picked"
    echo "$picked"; return 0
  fi
  echo ""; return 1
}

if [[ -z "$ACTIVE_THEME" || ! -d "$TARGET/wp-content/themes/$ACTIVE_THEME" ]]; then
  note_err "active theme directory not found (db: ${ACTIVE_THEME:-empty}); trying to self-heal…"
  ACTIVE_THEME="$(ensure_theme_ready "$ACTIVE_THEME")"
  run_wp theme list --status=active --format=json > "${LOGDIR}/theme_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/theme_active.json"
  run_wp theme list --format=json > "${LOGDIR}/themes.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/themes.json"
fi

THEME_FILES=0; THEME_SHA1=""
if [[ -n "$ACTIVE_THEME" && -d "$TARGET/wp-content/themes/$ACTIVE_THEME" ]]; then
  mkdir -p "${LOGDIR}/theme"
  (cd "$TARGET/wp-content/themes/$ACTIVE_THEME" && find . -type f | sort) > "${LOGDIR}/theme/tree.txt" || true
  (cd "$TARGET/wp-content/themes/$ACTIVE_THEME" && find . -type f -exec sha1sum {} \; | sort) > "${LOGDIR}/theme/hashes.sha1" || true
  [[ -s "${LOGDIR}/theme/tree.txt" ]] && THEME_FILES=$(wc -l < "${LOGDIR}/theme/tree.txt" || echo 0)
  [[ -s "${LOGDIR}/theme/hashes.sha1" ]] && THEME_SHA1=$(sha1sum "${LOGDIR}/theme/hashes.sha1" | awk '{print $1}')
else
  note_err "theme self-heal failed (no usable theme dir)."
fi

# ======================== C) PLUGINS (standard) ========================
run_wp plugin list --format=json > "${LOGDIR}/plugins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/plugins.json"
run_wp plugin list --format=csv > "${LOGDIR}/plugins.csv" 2>>"${ERR_FILE}" || echo '' > "${LOGDIR}/plugins.csv"
run_wp plugin list --status=active --field=name --format=json > "${LOGDIR}/plugins_active.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/plugins_active.json"
php -r '$p=getenv("P"); if(file_exists($p)){ $a=json_decode(file_get_contents($p),true)?:[]; foreach($a as $s) echo $s,PHP_EOL; }' P="${LOGDIR}/plugins_active.json" > "${LOGDIR}/plugins_active.txt" 2>/dev/null || true

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
if [[ ! -s "${LOGDIR}/plugins_trees.tsv" ]]; then
  note_err "plugins_trees.tsv is empty (no plugin file trees captured)."
fi

# ======================== D) MU-plugins (on + OFF pełny audyt) ========================
run_wp plugin list --status=must-use --format=json > "${LOGDIR}/mu_plugins.json" 2>>"${ERR_FILE}" || echo '[]' > "${LOGDIR}/mu_plugins.json"

MU_DIR="${TARGET}/wp-content/mu-plugins"
mkdir -p "${LOGDIR}/mu-plugins" "${LOGDIR}/mu-plugins/off_headers"
[[ -d "${MU_DIR}" ]] && ls -la "${MU_DIR}" > "${LOGDIR}/mu-plugins/_ls.txt" || echo "mu-plugins dir not found" > "${LOGDIR}/mu-plugins/_ls.txt"
[[ -d "${MU_DIR}" ]] && find "${MU_DIR}" -type f -exec sha1sum {} \; | sort > "${LOGDIR}/mu-plugins/_hashes.txt" || : > "${LOGDIR}/mu-plugins/_hashes.txt"

# ON: fingerprint po głównych plikach .php (szybkie porównanie)
: > "${LOGDIR}/mu_trees.tsv"   # slug \t files \t sha1 (tu 1 plik)
if [[ -d "${MU_DIR}" ]]; then
  for mu in "${MU_DIR}"/*.php; do
    [[ -f "$mu" ]] || continue
    slug="$(basename "$mu" .php)"
    SHA="$(sha1sum "$mu" | awk '{print $1}')"
    echo -e "${slug}\t1\t${SHA}" >> "${LOGDIR}/mu_trees.tsv"
  done
fi

# OFF: pełny audyt – lista, SHA1, nagłówki
: > "${LOGDIR}/mu_off.txt"
: > "${LOGDIR}/mu_off_fingerprints.tsv"  # file.off \t sha1
if [[ -d "${MU_DIR}" ]]; then
  shopt -s nullglob
  for off in "${MU_DIR}"/*.off; do
    [[ -f "$off" ]] || continue
    base="$(basename "$off")"
    echo "${base}" >> "${LOGDIR}/mu_off.txt"
    sha1sum "$off" | awk '{print $1}' >> "${LOGDIR}/mu_off_fingerprints.tsv"
    # nagłówek (Plugin Name) – jeśli to plik PHP z nagłówkiem (często .off to .php z innym rozszerzeniem)
    head -n 80 "$off" | grep -E "^\s*\*\s*Plugin Name:" -m1 > "${LOGDIR}/mu-plugins/off_headers/${base}.header.txt" || true
  done
  shopt -u nullglob
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

# ======================== I) WEB CAPTURE (HTML; PNG opcjonalne) ========================
SC_DIR="${LOGDIR}/screens"
mkdir -p "${SC_DIR}"
URLS=()
[[ -n "${SITE_URL}" ]] && URLS+=("${SITE_URL}")
[[ -n "${SITE_URL}" ]] && URLS+=("${SITE_URL%/}/wp-admin")
[[ -n "${SITE_URL}" ]] && URLS+=("${SITE_URL%/}/kontakt")

HAS_WKHTML=0
if command -v wkhtmltoimage >/dev/null 2>&1; then HAS_WKHTML=1; else note_err "wkhtmltoimage not found – PNG skipped (HTML saved)."; fi

for U in "${URLS[@]}"; do
  SAFE="$(echo "${U}" | sed -E 's#^https?://##; s#[^a-zA-Z0-9._-]+#_#g')"
  OUT="${SC_DIR}/${SAFE}"
  CODE="$(curl -sS -k -L -m 25 \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" \
    -D "${OUT}.headers" -o "${OUT}.html" -w "%{http_code}" "${U}" || echo "000")"
  echo -n "${CODE}" > "${OUT}.code"
  if [[ "${HAS_WKHTML}" -eq 1 ]]; then
    wkhtmltoimage --width 1366 --quality 70 "${U}" "${OUT}.png" >/dev/null 2>&1 || note_err "PNG capture failed for ${U}"
  fi
done

php -r '
  $d=getenv("SC_DIR"); $out=[];
  if (is_dir($d)) {
    foreach (glob($d."/*.html") as $html) {
      $base=preg_replace("/\.html$/","",$html);
      $code=@file_exists($base.".code")?trim(@file_get_contents($base.".code")):"";
      $hdr =@file_exists($base.".headers")?basename($base.".headers"):"";
      $png =@file_exists($base.".png")?basename($base.".png"):"";
      $url =preg_replace("#^.*?/screens/#","",$base);
      $out[]=["safe_id"=>$url,"code"=>$code,"html"=>basename($html),"headers"=>$hdr?:null,"png"=>$png?:null];
    }
  }
  echo json_encode($out, JSON_UNESCAPED_SLASHES|JSON_PRETTY_PRINT);
' > "${SC_DIR}/screens_index.json" 2>/dev/null || echo '[]' > "${SC_DIR}/screens_index.json"

# ======================== J) FINAL SNAPSHOT (PHP) ========================
TS_NOW="$(date -Is)"

# Zbierz MU OFF jako obiekty: file + sha1 + header (jeśli jest)
php -r '
  $dir=getenv("D");
  $list_file="$dir/mu_off.txt";
  $out=[];
  if(file_exists($list_file)){
    foreach(explode("\n",trim(file_get_contents($list_file))) as $f){
      if($f==="") continue;
      $sha = ""; $sha_list="$dir/mu_off_fingerprints.tsv";
      if(file_exists($sha_list)){
        foreach(explode("\n",trim(file_get_contents($sha_list))) as $row){
          $row=trim($row); if($row==="") continue;
          // fingerprint list: just sha per line (aligned to file order); fallback: blank
        }
      }
      // Spróbuj wczytać konkretny sha z MU dir jeśli plik istnieje
      $sha_try="";
      $mu_dir=getenv("MU_DIR");
      if($mu_dir && file_exists($mu_dir."/".$f)){
        $sha_try=trim(shell_exec("sha1sum ".escapeshellarg($mu_dir."/".$f)." | awk '{print $1}'"));
      }
      $sha = $sha_try ?: "";
      $hdr_path="$dir/mu-plugins/off_headers/".$f.".header.txt";
      $hdr=null; if(file_exists($hdr_path)){ $hdr=trim(file_get_contents($hdr_path)); if($hdr==="") $hdr=null; }
      $out[]=["file"=>$f,"sha1"=>$sha, "header"=>$hdr];
    }
  }
  echo json_encode($out, JSON_UNESCAPED_SLASHES|JSON_PRETTY_PRINT);
' D="${LOGDIR}" MU_DIR="${MU_DIR:-}" > "${LOGDIR}/mu_off_objects.json" 2>/dev/null || echo '[]' > "${LOGDIR}/mu_off_objects.json"

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
      while(($line=fgets($h))!==false){ $line=rtrim($line,"\r\n"); if($line==="") continue;
        [$slug,$files,$sha]=array_pad(explode("\t",$line),3,""); $m[$slug]=["files"=>(int)$files,"sha1"=>$sha]; }
      fclose($h); return $m;
    };
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
        "mu_off"=>$read("$L/mu_off_objects.json",[])
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
