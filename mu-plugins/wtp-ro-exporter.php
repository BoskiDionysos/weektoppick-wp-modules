<?php
/**
 * Plugin Name: WTP RO Exporter (Open)
 * Description: Publiczne endpointy REST do odczytu snapshotu oraz najnowszych logów (wp-debug/php_errors/mu-loader) z bezpiecznej lokalizacji.
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
            'file' => [
                'required' => true,
                'type'     => 'string',
            ],
        ],
    ]);

    // Kopiuje bieżące logi do katalogu public (wp-debug/php_errors/mu-loader)
    register_rest_route('wtp-ro-open/v1', '/emit-logs', [
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => 'wtp_ro_open_emit_logs',
    ]);
});

/** Pełna ścieżka do katalogu public snapshotu. */
function wtp_ro_public_base_abs(): string {
    $up = wp_get_upload_dir(); // ['basedir','baseurl','subdir','error']
    $base = trailingslashit($up['basedir']) . 'wtp-ro/public/' . WTP_RO_SITE_KEY . '/';
    return $base;
}

/** Biała lista nazw plików serwowanych przez /get. */
function wtp_ro_allowed_filenames(): array {
    $list = [
        // snapshot core
        'index.json'              => true,
        'manifest.json'           => true,
        'options.json'            => true,
        'selftest.json'           => true,
        'bundle.json'             => true,
        // nowy: pełny digest z GH
        'gh-digest.json'          => true,
        // health/diag publikowane przez workflowy
        'watchdog-last.json'      => true,
        'snapshot-sync-last.json' => true,
        // logi
        'wp-debug-latest.txt'     => true,
        'php_errors-latest.txt'   => true,
        'wp-debug-meta.json'      => true,
        'mu-loader-latest.txt'    => true,
        'errors-tail.txt'         => true,
    ];
    // files_000.json ... files_999.json
    for ($i=0; $i<=999; $i++) {
        $list[sprintf('files_%03d.json', $i)] = true;
    }
    return $list;
}

/** Zwraca listę plików snapshotu (tylko z dozwolonych nazw) w katalogu public. */
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

/** GET /wp-json/wtp-ro-open/v1/ls */
function wtp_ro_open_ls(WP_REST_Request $req) {
    $up = wp_get_upload_dir();
    $base_abs = wtp_ro_public_base_abs();
    $base_url = trailingslashit($up['baseurl']).'wtp-ro/public/'.WTP_RO_SITE_KEY.'/';

    $exists = [ 'dirA' => is_dir($base_abs), 'dirB' => is_dir($base_abs) ];
    $list   = [ 'dirA' => wtp_ro_list_public_files(), 'dirB' => wtp_ro_list_public_files() ];

    $resp = [
        'version'      => '1.6.1',
        'generated_at' => time(),
        'upload_dir'   => [
            'path'    => $up['path'],
            'url'     => $up['url'],
            'subdir'  => $up['subdir'],
            'basedir' => $up['basedir'],
            'baseurl' => $up['baseurl'],
            'error'   => $up['error'],
        ],
        'paths'      => [
            'dirA_abs'        => $base_abs,
            'dirB_wp_uploads' => $base_abs,
        ],
        'exists'     => $exists,
        'list'       => $list,
        'urls'       => [
            'baseurl'    => $up['baseurl'],
            'public_url' => $base_url,
        ],
    ];
    return new WP_REST_Response($resp, 200);
}

/**
 * GET /wp-json/wtp-ro-open/v1/get?file=<nazwa>
 * Serwuje pojedynczy plik z białej listy.
 * Zmiana: dla *.json zwracamy zdekodowany JSON jako tablicę/obiekt → WP zrobi prawdziwy JSON (bez stringa).
 */
function wtp_ro_open_get(WP_REST_Request $req) {
    $file = $req->get_param('file');
    if (!is_string($file) || $file === '') {
        return new WP_Error('bad_file', 'Invalid file name', ['status'=>400]);
    }
    $file = basename($file);
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

    // Dla JSON – spróbuj zdekodować i zwrócić strukturę
    if (str_ends_with($file, '.json')) {
        $decoded = json_decode($data, true);
        if (json_last_error() === JSON_ERROR_NONE) {
            return new WP_REST_Response($decoded, 200, ['Content-Type' => 'application/json; charset=UTF-8']);
        }
        // jeśli z jakiegoś powodu to nie jest poprawny JSON – zwróć czysty tekst (fallback)
    }

    return new WP_REST_Response($data, 200, ['Content-Type' => $ctype]);
}

/**
 * POST /wp-json/wtp-ro-open/v1/emit-logs
 * Kopiuje aktualne logi do public jako *-latest.txt + meta z mtime/size.
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

    // 1) WP DEBUG LOG — stała z wp-config lub bezpieczne lokalizacje
    $wp_debug_log = defined('WP_DEBUG_LOG') && is_string(WP_DEBUG_LOG) ? WP_DEBUG_LOG : '';
    $candidates_wp = array_filter([
        $wp_debug_log ?: null,
        WP_CONTENT_DIR.'/debug/wp-debug.log',
        ABSPATH.'wp-content/debug/wp-debug.log',
    ]);
    $src_wp_debug = wtp_ro_first_existing_file($candidates_wp);
    if ($src_wp_debug) {
        $dst = $dest_dir.'wp-debug-latest.txt';
        @copy($src_wp_debug, $dst);
        if (is_file($dst)) $wrote[] = 'wp-debug-latest.txt';
    } else {
        $warn[] = 'wp-debug.log not found';
    }

    // 2) PHP ERROR LOG — z ini error_log lub znane ścieżki
    $ini_log = ini_get('error_log');
    $candidates_php = array_filter([
        $ini_log ?: null,
        WP_CONTENT_DIR.'/debug/php_errors.log',
        ABSPATH.'wp-content/debug/php_errors.log',
    ]);
    $src_php_errors = wtp_ro_first_existing_file($candidates_php);
    if ($src_php_errors) {
        $dst = $dest_dir.'php_errors-latest.txt';
        @copy($src_php_errors, $dst);
        if (is_file($dst)) $wrote[] = 'php_errors-latest.txt';
    } else {
        $warn[] = 'php_errors.log not found';
    }

    // 3) MU Loader log (jeśli istnieje)
    $mu_loader_log = WP_CONTENT_DIR . '/uploads/wtp-ro/mu-loader.log';
    if (is_file($mu_loader_log)) {
        $dst = $dest_dir.'mu-loader-latest.txt';
        @copy($mu_loader_log, $dst);
        if (is_file($dst)) $wrote[] = 'mu-loader-latest.txt';
    }

    // 4) Zbiorczy tail błędów (ostatnie 200 linii z dwóch głównych logów, jeśli są)
    $errors_tail = '';
    foreach (['wp-debug-latest.txt','php_errors-latest.txt'] as $fn) {
        $p = $dest_dir.$fn;
        if (is_file($p)) {
            $errors_tail .= "===== $fn =====\n";
            $content = @file_get_contents($p);
            if (is_string($content)) {
                $lines = preg_split("/\r\n|\n|\r/", $content);
                $tail  = array_slice($lines, -200);
                $errors_tail .= implode("\n", $tail) . "\n\n";
            }
        }
    }
    if ($errors_tail !== '') {
        @file_put_contents($dest_dir.'errors-tail.txt', $errors_tail);
        if (is_file($dest_dir.'errors-tail.txt')) $wrote[] = 'errors-tail.txt';
    }

    // 5) meta o mtime/size
    $meta = [
        'ts'   => time(),
        'files'=> [],
    ];
    foreach (['wp-debug-latest.txt','php_errors-latest.txt','mu-loader-latest.txt','errors-tail.txt'] as $fn) {
        $p = $dest_dir.$fn;
        if (is_file($p)) {
            $meta['files'][$fn] = [
                'size'  => filesize($p),
                'mtime' => @filemtime($p),
            ];
        }
    }
    @file_put_contents($dest_dir.'wp-debug-meta.json', wp_json_encode($meta));
    if (is_file($dest_dir.'wp-debug-meta.json')) {
        $wrote[] = 'wp-debug-meta.json';
    }

    return new WP_REST_Response([
        'ok'       => true,
        'wrote'    => array_values(array_unique($wrote)),
        'warnings' => $warn,
    ], 200);
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

/** Polyfill dla PHP < 8 (str_ends_with) */
if (!function_exists('str_ends_with')) {
    function str_ends_with($haystack, $needle) {
        if ($needle === '') return true;
        $len = strlen($needle);
        return $len === 0 ? true : substr($haystack, -$len) === $needle;
    }
}
