<?php
/**
 * Plugin Name: WTP RO Exporter (Open)
 * Description: Publiczne endpointy REST do odczytu snapshotu oraz najnowszych logów (wp-debug/php_errors/MU loader) z bezpiecznej lokalizacji.
 * Version:     1.2.0
 * Author:      WTP
 */
if (!defined('ABSPATH')) exit;

/**
 * USTAWIENIA
 * ----------
 * SITE_KEY – katalog public snapshotu.
 * BASE_PUBLIC – wp-uploads/wtp-ro/public/<SITE_KEY>/
 */
define('WTP_RO_SITE_KEY', '5Depft8Y9LU0t6Sv');

add_action('rest_api_init', function () {
    register_rest_route('wtp-ro-open/v1', '/ls', [
        'methods'             => 'GET',
        'permission_callback' => '__return_true',
        'callback'            => 'wtp_ro_open_ls',
    ]);

    register_rest_route('wtp-ro-open/v1', '/get', [
        'methods'             => 'GET',
        'permission_callback' => '__return_true',
        'callback'            => 'wtp_ro_open_get',
        'args'                => [
            'file' => ['required' => true, 'type' => 'string'],
        ],
    ]);

    // Skopiuj bieżące logi do katalogu public jako *-latest.txt (+ meta + tail)
    register_rest_route('wtp-ro-open/v1', '/emit-logs', [
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => 'wtp_ro_open_emit_logs',
    ]);
});

/** Pełna ścieżka do katalogu public snapshotu. */
function wtp_ro_public_base_abs(): string {
    $up = wp_get_upload_dir(); // ['basedir','baseurl','subdir','error']
    return trailingslashit($up['basedir']) . 'wtp-ro/public/' . WTP_RO_SITE_KEY . '/';
}

/** Lista dozwolonych nazw plików zwracanych przez /get (biała lista). */
function wtp_ro_allowed_filenames(): array {
    $list = [
        // snapshot główny
        'index.json'               => true,
        'manifest.json'            => true,
        'options.json'             => true,
        'selftest.json'            => true,
        'bundle.json'              => true,
        'gh-digest.json'           => true,

        // logi + meta + tail
        'wp-debug-latest.txt'      => true,
        'php_errors-latest.txt'    => true,
        'mu-loader-latest.txt'     => true,
        'wp-debug-meta.json'       => true,
        'errors-tail.txt'          => true,

        // raporty z workflowów
        'watchdog-last.json'       => true,
        'snapshot-sync-last.json'  => true,
    ];
    // files_000.json ... files_999.json
    for ($i=0; $i<=999; $i++) {
        $list[sprintf('files_%03d.json', $i)] = true;
    }
    return $list;
}

/** Zwróć listę plików z katalogu public (tylko z białej listy). */
function wtp_ro_list_public_files(): array {
    $base = wtp_ro_public_base_abs();
    if (!is_dir($base)) return [];
    $allowed = wtp_ro_allowed_filenames();
    $out = [];
    $dh = @opendir($base);
    if (!$dh) return [];
    while (($f = readdir($dh)) !== false) {
        if ($f === '.' || $f === '..') continue;
        if (!isset($allowed[$f])) continue;
        if (is_file($base.$f)) $out[] = $f;
    }
    closedir($dh);
    sort($out);
    return $out;
}

/** GET /wp-json/wtp-ro-open/v1/ls – meta + lista plików public. */
function wtp_ro_open_ls(WP_REST_Request $req) {
    $up = wp_get_upload_dir();
    $base_abs = wtp_ro_public_base_abs();
    $base_url = trailingslashit($up['baseurl']).'wtp-ro/public/'.WTP_RO_SITE_KEY.'/';

    $resp = [
        'version'      => '1.2.0',
        'generated_at' => time(),
        'upload_dir'   => [
            'path'    => $up['path'],
            'url'     => $up['url'],
            'subdir'  => $up['subdir'],
            'basedir' => $up['basedir'],
            'baseurl' => $up['baseurl'],
            'error'   => $up['error'],
        ],
        'paths'        => [
            'public_abs' => $base_abs,
        ],
        'exists'       => [
            'public_dir' => is_dir($base_abs),
        ],
        'list'         => [
            'dirA' => wtp_ro_list_public_files(),
        ],
        'urls'         => [
            'baseurl'    => $up['baseurl'],
            'public_url' => $base_url,
        ],
    ];
    return new WP_REST_Response($resp, 200);
}

/** GET /wp-json/wtp-ro-open/v1/get?file=<nazwa> – serwuje plik z białej listy. */
function wtp_ro_open_get(WP_REST_Request $req) {
    $file = $req->get_param('file');
    if (!is_string($file) || $file === '') {
        return new WP_Error('bad_file', 'Invalid file name', ['status'=>400]);
    }
    $file = basename($file); // tylko nazwa bazowa (bez folderów)
    $allowed = wtp_ro_allowed_filenames();
    if (!isset($allowed[$file])) {
        return new WP_Error('bad_file', 'Invalid file name', ['status'=>400]);
    }
    $path = realpath(wtp_ro_public_base_abs() . $file);
    $base = realpath(wtp_ro_public_base_abs());
    if (!$path || !$base || strpos($path, $base) !== 0 || !is_file($path)) {
        return new WP_Error('not_found', 'File not found', ['status'=>404]);
    }
    $ctype = 'application/octet-stream';
    if (str_ends_with($file, '.json')) $ctype = 'application/json; charset=UTF-8';
    if (str_ends_with($file, '.txt'))  $ctype = 'text/plain; charset=UTF-8';

    $data = @file_get_contents($path);
    if ($data === false) {
        return new WP_Error('read_error', 'Cannot read file', ['status'=>500]);
    }
    return new WP_REST_Response($data, 200, ['Content-Type' => $ctype]);
}

/**
 * POST /wp-json/wtp-ro-open/v1/emit-logs
 * Kopiuje aktualne logi (jeśli istnieją) do katalogu public jako *-latest.txt,
 * generuje meta (wp-debug-meta.json) i skrócony tail (errors-tail.txt).
 */
function wtp_ro_open_emit_logs(WP_REST_Request $req) {
    $wrote = [];
    $warn  = [];

    $dest_dir = wtp_ro_public_base_abs();
    if (!is_dir($dest_dir)) {
        wp_mkdir_p($dest_dir);
    }
    if (!is_dir($dest_dir) || !is_writable($dest_dir)) {
        return new WP_Error('dest_error', 'Destination not writable', ['status'=>500]);
    }

    $user = wtp_ro_guess_user();

    // 1) WP DEBUG LOG
    $wp_debug_log = defined('WP_DEBUG_LOG') && is_string(WP_DEBUG_LOG) ? WP_DEBUG_LOG : '';
    $src_wp_debug = wtp_ro_first_existing_file(array_filter([
        $wp_debug_log ?: null,
        $user ? "/home/{$user}/debug/wp-debug.log" : null,
        WP_CONTENT_DIR.'/debug/wp-debug.log',
    ]));
    if ($src_wp_debug) {
        $dst = $dest_dir.'wp-debug-latest.txt';
        @copy($src_wp_debug, $dst);
        if (is_file($dst)) $wrote[] = 'wp-debug-latest.txt';
    } else {
        $warn[] = 'wp-debug.log not found';
    }

    // 2) PHP ERROR LOG
    $ini_log = ini_get('error_log');
    $src_php_errors = wtp_ro_first_existing_file(array_filter([
        $ini_log ?: null,
        $user ? "/home/{$user}/debug/php_errors.log" : null,
        WP_CONTENT_DIR.'/debug/php_errors.log',
    ]));
    if ($src_php_errors) {
        $dst = $dest_dir.'php_errors-latest.txt';
        @copy($src_php_errors, $dst);
        if (is_file($dst)) $wrote[] = 'php_errors-latest.txt';
    } else {
        $warn[] = 'php_errors.log not found';
    }

    // 3) MU LOADER LOG
    $src_mu = WP_CONTENT_DIR . '/uploads/wtp-ro/mu-loader.log';
    if (is_file($src_mu)) {
        $dst = $dest_dir.'mu-loader-latest.txt';
        @copy($src_mu, $dst);
        if (is_file($dst)) $wrote[] = 'mu-loader-latest.txt';
    } else {
        $warn[] = 'mu-loader.log not found';
    }

    // 4) META + TAIL
    $meta = ['ts'=>time(), 'files'=>[], 'warnings'=>$warn];
    $tail = "";
    foreach (['wp-debug-latest.txt','php_errors-latest.txt','mu-loader-latest.txt'] as $fn) {
        $p = $dest_dir.$fn;
        if (is_file($p)) {
            $meta['files'][$fn] = [
                'size'  => filesize($p),
                'mtime' => @filemtime($p),
            ];
            $lines = @file($p);
            if (is_array($lines)) {
                $slice = array_slice($lines, -200);
                $tail .= "\n===== {$fn} (last 200 lines) =====\n".implode('', $slice);
            }
        }
    }
    @file_put_contents($dest_dir.'wp-debug-meta.json', wp_json_encode($meta));
    if (is_file($dest_dir.'wp-debug-meta.json')) $wrote[] = 'wp-debug-meta.json';

    if ($tail !== '') {
        @file_put_contents($dest_dir.'errors-tail.txt', $tail);
        if (is_file($dest_dir.'errors-tail.txt')) $wrote[] = 'errors-tail.txt';
    }

    return new WP_REST_Response([
        'ok'       => true,
        'wrote'    => array_values(array_unique($wrote)),
        'warnings' => $warn,
    ], 200);
}

/** Polyfill dla PHP < 8 */
if (!function_exists('str_ends_with')) {
    function str_ends_with($haystack, $needle) {
        if ($needle === '') return true;
        $len = strlen($needle);
        return $len === 0 ? true : substr($haystack, -$len) === $needle;
    }
}

/** Helpers */
function wtp_ro_first_existing_file(array $paths) {
    foreach ($paths as $p) {
        if ($p && is_string($p)) {
            $rp = realpath($p);
            if ($rp && is_file($rp)) return $rp;
        }
    }
    return null;
}
function wtp_ro_guess_user() {
    if (function_exists('posix_geteuid') && function_exists('posix_getpwuid')) {
        $info = @posix_getpwuid(@posix_geteuid());
        if ($info && !empty($info['name'])) return $info['name'];
    }
    $home = getenv('HOME');
    if ($home) {
        $parts = explode('/', trim($home, '/'));
        return end($parts);
    }
    return null;
}
