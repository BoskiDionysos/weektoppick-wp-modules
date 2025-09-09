<?php
/**
 * Plugin Name: WTP Read-Only Exporter (open)
 * Description: Endpointy do snapshotu (lista/pobieranie) z uploads/wtp-ro/public/{site_key}/
 * Version: 1.1.1
 */
if (!defined('ABSPATH')) exit;

define('WTP_RO_EXPORTER_NS', 'wtp-ro-open/v1');
$wtp_ro_default_site_key = '5Depft8Y9LU0t6Sv';

function wtp_ro_exporter_base_dir() {
    $dir = WP_CONTENT_DIR . '/uploads/wtp-ro/public/';
    return rtrim($dir, '/').'/';
}
function wtp_ro_sanitize_site_key($raw, $fallback) {
    $k = (is_string($raw) && $raw !== '') ? $raw : $fallback;
    $k = preg_replace('/[^A-Za-z0-9]/', '', $k);
    if ($k === '') $k = $fallback;
    return $k;
}

add_filter('rest_pre_serve_request', function ($served, $result, $request, $server) {
    $route = $request->get_route();
    if (strpos($route, '/'.WTP_RO_EXPORTER_NS.'/') !== false) {
        @header('Access-Control-Allow-Origin: *');
        @header('Access-Control-Allow-Methods: GET, OPTIONS');
        @header('Access-Control-Allow-Headers: *');
        @header('Cache-Control: no-cache, no-store, must-revalidate');
        @header('Pragma: no-cache');
        @header('Expires: 0');
    }
    return $served;
}, 10, 4);

add_action('rest_api_init', function () use ($wtp_ro_default_site_key) {

    register_rest_route(WTP_RO_EXPORTER_NS, '/health', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function (\WP_REST_Request $req) use ($wtp_ro_default_site_key) {
            $site_key = wtp_ro_sanitize_site_key($req->get_param('site_key'), $wtp_ro_default_site_key);
            $base = wtp_ro_exporter_base_dir();
            $dir  = $base.$site_key;
            $ok   = is_dir($dir);
            return new \WP_REST_Response([
                'ok'       => $ok ? true : false,
                'site_key' => $site_key,
                'base'     => $base,
                'dir'      => $dir,
                'ts'       => time(),
            ], 200);
        }
    ]);

    register_rest_route(WTP_RO_EXPORTER_NS, '/ls', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function (\WP_REST_Request $req) use ($wtp_ro_default_site_key) {
            $site_key = wtp_ro_sanitize_site_key($req->get_param('site_key'), $wtp_ro_default_site_key);
            $base     = wtp_ro_exporter_base_dir();
            $root     = realpath($base);
            $dir      = realpath($base.$site_key);

            if (!$root || !$dir || strpos($dir, $root) !== 0 || !is_dir($dir)) {
                return new \WP_REST_Response([
                    'version'      => '1.5.0',
                    'generated_at' => time(),
                    'url'          => content_url("/uploads/wtp-ro/public/{$site_key}"),
                    'files'        => [],
                    'manifest'     => 'manifest.json',
                    'options'      => 'options.json',
                    'selftest'     => 'selftest.json',
                ], 200);
            }

            $list = [];
            $dh = opendir($dir);
            if ($dh) {
                while (($f = readdir($dh)) !== false) {
                    if ($f === '.' || $f === '..') continue;
                    $real = realpath($dir.'/'.$f);
                    if (!$real || strpos($real, $dir) !== 0) continue;
                    if (is_file($real)) $list[] = $f;
                }
                closedir($dh);
            }
            sort($list, SORT_STRING);

            return new \WP_REST_Response([
                'version'      => '1.5.0',
                'generated_at' => time(),
                'url'          => content_url("/uploads/wtp-ro/public/{$site_key}"),
                'files'        => $list,
                'manifest'     => 'manifest.json',
                'options'      => 'options.json',
                'selftest'     => 'selftest.json',
            ], 200);
        }
    ]);

    register_rest_route(WTP_RO_EXPORTER_NS, '/get', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => => function (\WP_REST_Request $req) use ($wtp_ro_default_site_key) {

    $site_key = wtp_ro_sanitize_site_key($req->get_param('site_key'), $wtp_ro_default_site_key);
    $file = $req->get_param('file');

    if (!is_string($file) || $file === '') {
      return new \WP_Error('bad_file', 'Invalid file name', ['status' => 400]);
    }
    if (!preg_match('/^[A-Za-z0-9._-]+$/', $file)) {
      return new \WP_Error('bad_file', 'Invalid file name', ['status' => 400]);
    }

    $base = wtp_ro_exporter_base_dir();
    $root = realpath($base);
    $dir  = realpath($base.$site_key);
    if (!$root || !$dir || strpos($dir, $root) !== 0) {
      return new \WP_Error('not_found', 'Base path not found', ['status' => 404]);
    }

    $path = realpath($dir.'/'.$file);
    if (!$path || strpos($path, $dir) !== 0 || !is_file($path)) {
      return new \WP_Error('not_found', 'File not found', ['status' => 404]);
    }

    $data = @file_get_contents($path);
    if ($data === false) {
      return new \WP_Error('read_error', 'Could not read file', ['status' => 500]);
    }

    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    if ($ext === 'json') {
      $decoded = json_decode($data, true);
      if (json_last_error() !== JSON_ERROR_NONE) {
        return new \WP_Error('json_error', 'Invalid JSON', ['status' => 500]);
      }
      return new \WP_REST_Response($decoded, 200, ['Content-Type' => 'application/json; charset=UTF-8']);
    }

    // .txt lub inne – zwracamy jako plain text/binarnie
    $ct = ($ext === 'txt') ? 'text/plain; charset=UTF-8' : 'application/octet-stream';
    return new \WP_REST_Response($data, 200, ['Content-Type' => $ct]);
  }
]);
