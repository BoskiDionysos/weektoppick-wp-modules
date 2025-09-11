<?php
/**
 * Plugin Name: WTP Exporter Chunked — GitHub (plugins only)
 * Description: Eksportuje WSZYSTKIE wtyczki (plugins + mu-plugins) do wielu plików JSON < 5 MB + generuje indeks. Push do GitHub.
 * Version: 1.1.0
 */
if (!defined('ABSPATH')) exit;

/* Twardsze limity na czas eksportu (unikamy fatal/timeout przy dużych instalacjach) */
@ini_set('memory_limit', '512M');
@set_time_limit(120);

/*
 * WYMAGANE w wp-config.php:
 * define('WTP_GH_OWNER',  'BoskiDionysos');
 * define('WTP_GH_REPO',   'weektoppick-wp-modules');
 * define('WTP_GH_BRANCH', 'main');            // opcjonalnie (domyślnie 'main')
 * define('WTP_GH_TOKEN',  'ghp_xxx');         // PAT z repo:contents write
 * define('WTP_GH_SECRET', 'twoj_sekret');     // do REST (param <secret>)
 */

$need = ['WTP_GH_OWNER','WTP_GH_REPO','WTP_GH_TOKEN','WTP_GH_SECRET'];
foreach ($need as $c) { if (!defined($c)) { error_log("[WTP ExporterChunked] Missing constant $c"); return; } }

/** ───────────────────────────────────────────────────────────────────────────
 *  KONFIG
 *  ─────────────────────────────────────────────────────────────────────────── */
const WTP_ALLOWED_EXT        = ['php','css','js','json','svg','txt','md','html','po','mo'];
const WTP_EXCLUDE_RX         = '#(?:^|/)(node_modules|vendor|\.git|\.svn|\.github|tests?|bin|dist|cache)(/|$)#i';
const WTP_EXCLUDE_FILE_RX    = '#\.(map|lock|min\.map|ico|woff2?|ttf|eot)$#i';
const WTP_CHUNK_TARGET_BYTES = 5_000_000; // ~5 MB
const WTP_INDEX_PATH         = 'plugins-index.json';     // w repo (root)
const WTP_CHUNK_BASENAME     = 'plugins-bundle';         // prefix nazw chunków

add_action('rest_api_init', function () {

    // /wp-json/wtp-ro/v1/publish/plugins-chunked/<secret>
    register_rest_route('wtp-ro/v1', '/publish/plugins-chunked/(?P<secret>[^/]+)', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $req) {
            if ($req->get_param('secret') !== constant('WTP_GH_SECRET')) {
                return new WP_REST_Response(['ok'=>false,'error'=>'forbidden'], 403);
            }

            $t0 = microtime(true);
            $bundle = wtp_collect_plugins_fs_map();                  // mapa "plugins/... => content"
            if (!$bundle) return new WP_REST_Response(['ok'=>false,'error'=>'empty-plugins'], 500);

            $chunks = wtp_chunk_map($bundle, WTP_CHUNK_TARGET_BYTES); // [ [k=>v,...], ... ]
            if (empty($chunks)) return new WP_REST_Response(['ok'=>false,'error'=>'chunking-failed'], 500);

            // push wszystkich chunków + indeksu do GitHub
            $push = wtp_push_chunks_and_index_to_github($chunks);
            if (is_wp_error($push)) {
                return new WP_REST_Response(['ok'=>false,'error'=>$push->get_error_message()], 500);
            }

            $push['t_sec'] = round(microtime(true) - $t0, 3);
            $push['mem_mb'] = round(memory_get_usage(true)/1048576, 1);
            return new WP_REST_Response(['ok'=>true] + $push, 200);
        }
    ]);

    // /wp-json/wtp-ro/v1/publish/plugins-chunked-debug/<secret>  (BEZ pushu – diagnostyka)
    register_rest_route('wtp-ro/v1', '/publish/plugins-chunked-debug/(?P<secret>[^/]+)', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $req) {
            if ($req->get_param('secret') !== constant('WTP_GH_SECRET')) {
                return new WP_REST_Response(['ok'=>false,'error'=>'forbidden'], 403);
            }
            $t0 = microtime(true);
            $bundle = wtp_collect_plugins_fs_map();
            if (!$bundle) return new WP_REST_Response(['ok'=>false,'error'=>'empty-plugins'], 500);

            $chunks = wtp_chunk_map($bundle, WTP_CHUNK_TARGET_BYTES);
            $t1 = microtime(true);

            return new WP_REST_Response([
                'ok'           => true,
                'files_total'  => count($bundle),
                'chunks_total' => count($chunks),
                'mem_mb'       => round(memory_get_usage(true)/1048576, 1),
                'time_sec'     => round($t1 - $t0, 3),
                'chunk_sizes'  => array_map(function($m){
                    $s = json_encode($m, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);
                    return strlen($s);
                }, $chunks),
                'sample'       => array_slice(array_keys($bundle), 0, 10),
            ], 200);
        }
    ]);
});

/** ───────────────────────────────────────────────────────────────────────────
 *  ZBIERANIE: wszystkie wtyczki (plugins + mu-plugins) -> mapa "prefix/relpath" => content
 *  ─────────────────────────────────────────────────────────────────────────── */
function wtp_collect_plugins_fs_map() {
    $out = [];

    $plugins_base = wp_normalize_path(WP_PLUGIN_DIR);
    if (is_dir($plugins_base)) {
        $out += wtp_collect_from_base($plugins_base, 'plugins');
    }

    $mu_base = wp_normalize_path(WPMU_PLUGIN_DIR);
    if (is_dir($mu_base) && $mu_base !== $plugins_base) {
        $out += wtp_collect_from_base($mu_base, 'mu-plugins');
    }
    return $out;
}

function wtp_collect_from_base($base, $prefix) {
    $rii = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($base, FilesystemIterator::SKIP_DOTS));
    $out = [];
    foreach ($rii as $spl) {
        if (!$spl->isFile()) continue;
        $path = wp_normalize_path($spl->getPathname());
        $rel  = ltrim(str_replace($base, '', $path), '/');

        if (preg_match(WTP_EXCLUDE_RX, $rel)) continue;
        if (preg_match(WTP_EXCLUDE_FILE_RX, $rel)) continue;

        $ext = strtolower(pathinfo($rel, PATHINFO_EXTENSION));
        if (!in_array($ext, WTP_ALLOWED_EXT, true)) continue;

        $content = @file_get_contents($path);
        if ($content === false) continue;

        $key = trim($prefix, '/').'/'.$rel; // np. "plugins/akismet/akismet.php"
        $out[$key] = $content;
    }
    return $out;
}

/** ───────────────────────────────────────────────────────────────────────────
 *  CHUNKING: dzieli mapę (k=>v) na paczki < limit (po JSON-encode)
 *  ─────────────────────────────────────────────────────────────────────────── */
function wtp_chunk_map(array $map, int $targetBytes) {
    $chunks = [];
    $current = [];
    $approxBytes = 2; // nawiasy {}

    foreach ($map as $k => $v) {
        // oszacuj rozmiar przy JSON (klucz+wartość jako string) – z SUBSTITUE dla bezpieczeństwa
        $entryJson   = json_encode([$k => $v], JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);
        $entryBytes  = strlen($entryJson) + 1;

        if ($approxBytes + $entryBytes > $targetBytes && !empty($current)) {
            $chunks[] = $current;
            $current = [];
            $approxBytes = 2;
        }
        $current[$k] = $v;
        $approxBytes += $entryBytes;
    }
    if (!empty($current)) $chunks[] = $current;
    return $chunks;
}

/** ───────────────────────────────────────────────────────────────────────────
 *  PUSH: pliki chunków + indeks do GitHub (contents API)
 *  ─────────────────────────────────────────────────────────────────────────── */
function wtp_push_chunks_and_index_to_github(array $chunks) {
    $owner  = constant('WTP_GH_OWNER');
    $repo   = constant('WTP_GH_REPO');
    $branch = defined('WTP_GH_BRANCH') ? constant('WTP_GH_BRANCH') : 'main';
    $token  = constant('WTP_GH_TOKEN');

    $pushed = [];
    foreach ($chunks as $i => $payloadMap) {
        $payload = json_encode(
            $payloadMap,
            JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT|JSON_INVALID_UTF8_SUBSTITUTE
        );
        $path    = sprintf('%s_%03d.json', WTP_CHUNK_BASENAME, $i);
        $put     = wtp_gh_put_file($owner, $repo, $branch, $token, $path, $payload, 'Update '.$path.' (chunk)');
        if ($put['code'] >= 300) {
            return new WP_Error('wtp_github_put', 'GitHub PUT error '.$put['code'].': '.json_encode($put['body']));
        }
        $pushed[] = [
            'path' => $path,
            'size' => strlen($payload),
            'sha1' => sha1($payload),
            'raw'  => "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/{$path}"
        ];
    }

    // Zbuduj indeks
    $index = [
        'version'      => 1,
        'generated_at' => time(),
        'chunks'       => $pushed,
        'total_chunks' => count($pushed),
    ];
    $indexJson = json_encode($index, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);
    $putIndex  = wtp_gh_put_file($owner, $repo, $branch, $token, WTP_INDEX_PATH, $indexJson, 'Update '.WTP_INDEX_PATH.' (index)');
    if ($putIndex['code'] >= 300) {
        return new WP_Error('wtp_github_put', 'GitHub PUT index error '.$putIndex['code'].': '.json_encode($putIndex['body']));
    }

    return [
        'index_raw_url' => "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/".WTP_INDEX_PATH,
        'chunks'        => $pushed,
    ];
}

function wtp_gh_put_file($owner,$repo,$branch,$token,$path,$content,$message) {
    $api = "https://api.github.com/repos/{$owner}/{$repo}/contents/{$path}";
    // get sha if exists
    $sha = null;
    $get = wtp_http('GET', $api.'?ref='.rawurlencode($branch), $token, null);
    if ($get['code'] === 200 && !empty($get['body']['sha'])) $sha = $get['body']['sha'];

    $body = [
        'message' => $message,
        'content' => base64_encode($content),
        'branch'  => $branch,
    ];
    if ($sha) $body['sha'] = $sha;

    return wtp_http('PUT', $api, $token, $body);
}

function wtp_http($method, $url, $token, $json) {
    $args = [
        'method'  => $method,
        'headers' => [
            'Authorization' => 'token '.$token,
            'User-Agent'    => 'WTP-Exporter-Chunked',
            'Accept'        => 'application/vnd.github+json',
        ],
        'timeout' => 30,
    ];
    if ($json !== null) {
        $args['body'] = json_encode($json);
        $args['headers']['Content-Type'] = 'application/json';
    }
    $res  = wp_remote_request($url, $args);
    $code = wp_remote_retrieve_response_code($res);
    $body = json_decode(wp_remote_retrieve_body($res), true);
    return ['code'=>$code, 'body'=>$body];
}
