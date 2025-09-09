<?php
/**
 * Plugin Name: WTP RO Exporter (Open)
 * Description: Publiczne endpointy REST do odczytu snapshotu oraz najnowszych logów (wp-debug/php_errors) z bezpiecznej lokalizacji.
 * Version:     1.1.0
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

    // Pomocniczy endpoint: skopiuje bieżące logi do katalogu public (wp-debug-latest.txt / php_errors-latest.txt)
    // Cel: aby GHA mogło je pobrać bez grzebania w prywatnych ścieżkach.
    register_rest_route('wtp-ro-open/v1', '/emit-logs', [
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => 'wtp_ro_open_emit_logs',
    ]);
});

/**
 * Pełna ścieżka do katalogu public snapshotu.
 */
function wtp_ro_public_base_abs(): string {
    $up = wp_get_upload_dir(); // ['basedir','baseurl','subdir','error']
    $base = trailingslashit($up['basedir']) . 'wtp-ro/public/' . WTP_RO_SITE_KEY . '/';
    return $base;
}

/**
 * Zwraca listę plików snapshotu (tylko z dozwolonych nazw) w katalogu public.
 */
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

/**
 * Biała lista nazw plików udostępnianych przez /get.
 */
function wtp_ro_allowed_filenames(): array {
    $list = [
        'index.json'        => true,
        'manifest.json'     => true,
        'options.json'      => true,
        'selftest.json'     => true,
        'bundle.json'       => true,
        'wp-debug-latest.txt'     => true,
        'php_errors-latest.txt'   => true,
        'wp-debug-meta.json'      => true,
    ];
    // files_000.json ... files_020.json (lub więcej — w razie rozbudowy)
    for ($i=0; $i<=999; $i++) {
        $list[sprintf('files_%03d.json', $i)] = true;
    }
    return $list;
}

/**
 * GET /wp-json/wtp-ro-open/v1/ls
 * Zwraca meta oraz listę plików w katalogu public.
 */
function wtp_ro_open_ls(WP_REST_Request $req) {
    $up = wp_get_upload_dir();
    $base_abs = wtp_ro_public_base_abs();
    $base_url = trailingslashit($up['baseurl']).'wtp-ro/public/'.WTP_RO_SITE_KEY.'/';

    $exists = [
        'dirA' => is_dir($base_abs),
        'dirB' => is_dir($base_abs), // kompat: wcześniej zwracaliśmy dwa identyczne pola
    ];
    $list = [
        'dirA' => wtp_ro_list_public_files(),
        'dirB' => wtp_ro_list_public_files(),
    ];

    $resp = [
        'version'    => '1.6.0',
        'generated_at' => time(),
        'upload_dir' => [
            'path'    => $up['path'],
            'url'     => $up['url'],
            'subdir'  => $up['subdir'],
            'basedir' => $up['basedir'],
            'baseurl' => $up['baseurl'],
            'error'   => $up['error'],
        ],
        'paths'      => [
            'dirA_abs'      => $base_abs,
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
 */
function wtp_ro_open_get(WP_REST_Request $req) {
    $file = $req->get_param('file');
    if (!is_string($file) || $file === '') {
        return new WP_Error('bad_file', 'Invalid file name', ['status'=>400]);
    }
    // tylko nazwa bazowa, bez folderów
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
    // content-type
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
 * Kopiuje aktualne logi (jeśli istnieją) do katalogu public jako *-latest.txt
 * oraz dopisuje prosty meta-json z timestampami.
 *
 * Zwraca: { ok: true, wrote: [..], warnings:[..] }
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

    // 1) WP DEBUG LOG — jeśli stała ścieżka z wp-config:
    $wp_debug_log = defined('WP_DEBUG_LOG') && is_string(WP_DEBUG_LOG) ? WP_DEBUG_LOG : '';
    // fallback: poszukaj w bezpiecznych miejscach
    $candidates_wp = array_filter([
        $wp_debug_log ?: null,
        // najczęstsze lokalizacje w tym projekcie:
        '/home/'.wtp_ro_guess_user().'/debug/wp-debug.log',
        WP_CONTENT_DIR.'/debug/wp-debug.log',
    ]);
    $src_wp_debug = wtp_ro_first_existing_file($candidates_wp);
    if ($src_wp_debug) {
        $dst = $dest_dir.'wp-debug-latest.txt';
        @copy($src_wp_debug, $dst);
        if (is_file($dst)) $wrote[] = 'wp-debug-latest.txt';
    } else {
        $warn[] = 'wp-debug.log not found';
    }

    // 2) PHP ERROR LOG — z ini error_log lub nasza ścieżka z wp-config
    $ini_log = ini_get('error_log');
    $candidates_php = array_filter([
        $ini_log ?: null,
        '/home/'.wtp_ro_guess_user().'/debug/php_errors.log',
        WP_CONTENT_DIR.'/debug/php_errors.log',
    ]);
    $src_php_errors = wtp_ro_first_existing_file($candidates_php);
    if ($src_php_errors) {
        $dst = $dest_dir.'php_errors-latest.txt';
        @copy($src_php_errors, $dst);
        if (is_file($dst)) $wrote[] = 'php_errors-latest.txt';
    } else {
        $warn[] = 'php_errors.log not found';
    }

    // 3) proste meta o mtime/size
    $meta = [
        'ts'   => time(),
        'files'=> [],
    ];
    foreach (['wp-debug-latest.txt','php_errors-latest.txt'] as $fn) {
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

/**
 * Helpers
 */
function wtp_ro_first_existing_file(array $paths) {
    foreach ($paths as $p) {
        if ($p && is_string($p)) {
            $rp = realpath($p);
            if ($rp && is_file($rp)) return $rp;
        }
    }
    return null;
