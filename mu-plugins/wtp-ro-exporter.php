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
    return new WP_REST_Response($data, 200, ['Content-Type' => $ctype]);
}
