<?php
/**
 * Plugin Name: WTP Patcher — Plugins (from chunked index)
 * Description: Patchuje wszystkie (lub wybrane) wtyczki z GitHuba na podstawie plugins-index.json + chunków.
 * Version: 1.0.0
 */
if (!defined('ABSPATH')) exit;

/**
 * WYMAGANE w wp-config.php (jak przy eksporcie):
 * define('WTP_GH_OWNER',  'BoskiDionysos');
 * define('WTP_GH_REPO',   'weektoppick-wp-modules');
 * define('WTP_GH_BRANCH', 'main'); // opcjonalnie (domyślnie main)
 * define('WTP_GH_SECRET', '...');  // ten sam sekret co przy eksporcie
 */

add_action('rest_api_init', function () {

    // Wariant z parametrami: /wp-json/wtp-ro/v1/patch-plugins?key=...&index=...&dry=0&only=slug1,slug2
    register_rest_route('wtp-ro/v1', '/patch-plugins', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $req) {
            if (!wtp_pp_auth_ok($req)) {
                return new WP_REST_Response(['ok'=>false,'error'=>'forbidden'], 403);
            }
            $indexUrl = trim((string)$req->get_param('index'));
            if ($indexUrl === '') {
                // domyślny index z GH raw
                $owner  = defined('WTP_GH_OWNER')  ? constant('WTP_GH_OWNER')  : '';
                $repo   = defined('WTP_GH_REPO')   ? constant('WTP_GH_REPO')   : '';
                $branch = defined('WTP_GH_BRANCH') ? constant('WTP_GH_BRANCH') : 'main';
                if (!$owner || !$repo) {
                    return new WP_REST_Response(['ok'=>false,'error'=>'missing-index-and-defaults'], 400);
                }
                $indexUrl = "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/plugins-index.json";
            }

            $dry  = (string)$req->get_param('dry') === '1' || (string)$req->get_param('dry') === 'true';
            $only = array_filter(array_map('trim', explode(',', (string)$req->get_param('only'))));

            $result = wtp_pp_apply_from_index($indexUrl, $dry, $only);
            $code   = ($result['ok'] ?? false) ? 200 : 500;
            return new WP_REST_Response($result, $code);
        }
    ]);

    // Krótszy wariant: /wp-json/wtp-ro/v1/patch/plugins/<secret>?index=...&dry=0&only=...
    register_rest_route('wtp-ro/v1', '/patch/plugins/(?P<secret>[^/]+)', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $req) {
            $sec = (string)$req->get_param('secret');
            if (!defined('WTP_GH_SECRET') || $sec !== constant('WTP_GH_SECRET')) {
                return new WP_REST_Response(['ok'=>false,'error'=>'forbidden'], 403);
            }
            $indexUrl = trim((string)$req->get_param('index'));
            if ($indexUrl === '') {
                $owner  = defined('WTP_GH_OWNER')  ? constant('WTP_GH_OWNER')  : '';
                $repo   = defined('WTP_GH_REPO')   ? constant('WTP_GH_REPO')   : '';
                $branch = defined('WTP_GH_BRANCH') ? constant('WTP_GH_BRANCH') : 'main';
                if (!$owner || !$repo) {
                    return new WP_REST_Response(['ok'=>false,'error'=>'missing-index-and-defaults'], 400);
                }
                $indexUrl = "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/plugins-index.json";
            }
            $dry  = (string)$req->get_param('dry') === '1' || (string)$req->get_param('dry') === 'true';
            $only = array_filter(array_map('trim', explode(',', (string)$req->get_param('only'))));

            $result = wtp_pp_apply_from_index($indexUrl, $dry, $only);
            $code   = ($result['ok'] ?? false) ? 200 : 500;
            return new WP_REST_Response($result, $code);
        }
    ]);
});

/** Autoryzacja: ?key=… lub nagłówki */
function wtp_pp_auth_ok(WP_REST_Request $req) {
    if (!defined('WTP_GH_SECRET')) return false;
    $want = constant('WTP_GH_SECRET');

    $key = $req->get_param('key');
    if (is_string($key) && hash_equals($want, $key)) return true;

    $hdr = $req->get_header('X-WTP-Secret');
    if (is_string($hdr) && hash_equals($want, $hdr)) return true;

    $auth = $req->get_header('Authorization');
    if (is_string($auth) && stripos($auth, 'Bearer ') === 0) {
        $b = trim(substr($auth, 7));
        if (hash_equals($want, $b)) return true;
    }
    return false;
}

/**
 * Główna logika: pobiera index, pobiera wszystkie chunki, scala mapę i zapisuje pliki.
 *
 * @param string $indexUrl URL do plugins-index.json
 * @param bool   $dry      true = symulacja
 * @param array  $onlySlugs lista slugów (opcjonalnie), np. ['akismet','classic-editor']
 */
function wtp_pp_apply_from_index($indexUrl, $dry=false, array $onlySlugs=[]) {
    $resp = [
        'ok'        => false,
        'index'     => $indexUrl,
        'dry_run'   => (bool)$dry,
        'only'      => $onlySlugs,
        'created'   => [],
        'updated'   => [],
        'skipped'   => [],
        'errors'    => [],
        'chunks'    => [],
    ];

    $index = wtp_pp_http_get_json($indexUrl);
    if (!is_array($index) || empty($index['chunks']) || !is_array($index['chunks'])) {
        $resp['errors'][] = 'bad-index';
        return $resp;
    }

    // Zbierz wszystkie chunki do jednej mapy
    $bundle = []; // "plugins/... => content" albo "mu-plugins/... => content"
    foreach ($index['chunks'] as $row) {
        $url = $row['raw'] ?? $row['url'] ?? null;
        if (!$url) continue;
        $resp['chunks'][] = $url;

        $part = wtp_pp_http_get_json($url);
        if (!is_array($part)) {
            $resp['errors'][] = 'bad-chunk: '.$url;
            continue;
        }
        // merge, chunki mają unikalne klucze
        foreach ($part as $k => $v) {
            $bundle[$k] = $v;
        }
    }
    if (!$bundle) {
        $resp['errors'][] = 'empty-bundle';
        return $resp;
    }

    // Filtr ONLY (po slugu wtyczki dla prefixu "plugins/")
    $onlySlugs = array_map('strtolower', $onlySlugs);
    if ($onlySlugs) {
        $bundle = array_filter($bundle, function($v, $k) use ($onlySlugs) {
            if (strpos($k, 'plugins/') === 0) {
                // plugins/<slug>/...
                $rest = substr($k, 8);
                $slug = strtolower(strtok($rest, '/'));
                return in_array($slug, $onlySlugs, true);
            }
            if (strpos($k, 'mu-plugins/') === 0) {
                $rest = substr($k, 11);
                $slug = strtolower(strtok($rest, '/'));
                return in_array($slug, $onlySlugs, true);
            }
            return false;
        }, ARRAY_FILTER_USE_BOTH);
        if (!$bundle) {
            $resp['errors'][] = 'only-filter-empty';
            return $resp;
        }
    }

    // Zapis na dysk
    foreach ($bundle as $key => $content) {
        if (!is_string($content)) $content = (string)$content;

        if (strpos($key, 'plugins/') === 0) {
            $base = wp_normalize_path(WP_PLUGIN_DIR);
            $rel  = substr($key, 8); // bez "plugins/"
        } elseif (strpos($key, 'mu-plugins/') === 0) {
            $base = wp_normalize_path(WPMU_PLUGIN_DIR);
            $rel  = substr($key, 11); // bez "mu-plugins/"
        } else {
            $resp['skipped'][] = $key;
            continue;
        }

        $target = $base . '/' . $rel;
        $target = wp_normalize_path($target);
        $dir    = dirname($target);

        if ($dry) {
            if (file_exists($target)) $resp['updated'][] = $key;
            else                      $resp['created'][] = $key;
            continue;
        }

        if (!is_dir($dir)) {
            if (!wp_mkdir_p($dir)) {
                $resp['errors'][] = 'mkdir-failed: '.$dir;
                continue;
            }
        }

        $exists = file_exists($target);
        $ok     = @file_put_contents($target, $content);
        if ($ok === false) {
            $resp['errors'][] = 'write-failed: '.$target;
            continue;
        }
        if ($exists) $resp['updated'][] = $key;
        else         $resp['created'][] = $key;
    }

    $resp['ok'] = empty($resp['errors']);
    return $resp;
}

/** GET JSON helper (bez zewn. bibliotek) */
function wtp_pp_http_get_json($url) {
    $args = [
        'method'  => 'GET',
        'timeout' => 25,
        'headers' => ['Accept' => 'application/json'],
    ];
    $res  = wp_remote_request($url, $args);
    if (is_wp_error($res)) return null;
    $code = wp_remote_retrieve_response_code($res);
    if ($code < 200 || $code >= 300) return null;
    $body = wp_remote_retrieve_body($res);
    $json = json_decode($body, true);
    return is_array($json) ? $json : null;
}
