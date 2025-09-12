<?php
/**
 * Plugin Name: WTP Deploy Guard
 * Description: Twarde blokady edycji z panelu + publiczny endpoint health do CI/CD.
 * Author: WeekTopPick
 * Version: 1.0.0
 */
if (!defined('ABSPATH')) { exit; }

/**
 * 1) Schowaj edytory plików w panelu (gdyby ktoś zdjął DISALLOW_* w wp-config).
 */
add_action('admin_menu', function () {
    remove_submenu_page('themes.php', 'theme-editor.php');
    remove_submenu_page('plugins.php', 'plugin-editor.php');
}, 999);

/**
 * 2) Twardo zablokuj operacje plikowe z panelu (hardening na wypadek zmiany wp-config).
 *    Nie nadpisujemy stałych, ale filtr "filesystem_method" i "automatic_updater_disabled"
 *    dopina blokadę po stronie runtime.
 */
add_filter('filesystem_method', function () { return 'direct'; }, 999);
add_filter('automatic_updater_disabled', '__return_true', 999);
add_filter('auto_update_core', '__return_false', 999);
add_filter('auto_update_plugin', '__return_false', 999);
add_filter('auto_update_theme', '__return_false', 999);
add_filter('plugins_api_result', function ($res) { return new WP_Error('wtp_locked', 'Updates disabled by WTP LOCKS'); }, 999);

/**
 * 3) Publiczny healthcheck (CI uderza lokalnie 127.0.0.1).
 *    GET /wp-json/wtp-ro-open/v1/health
 */
add_action('rest_api_init', function () {
    register_rest_route('wtp-ro-open/v1', '/health', [
        'methods'  => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function () {
            global $wpdb;

            // Szybkie testy środowiska
            $db_ok = false;
            try {
                $db_ok = (bool) $wpdb->query('SELECT 1');
            } catch (\Throwable $e) {
                $db_ok = false;
            }

            // Sprawdzenia kluczowych plików/struktur
            $root = WP_CONTENT_DIR;
            $checks = [
                'plugins_dir'     => is_dir(WP_CONTENT_DIR . '/plugins'),
                'themes_dir'      => is_dir(WP_CONTENT_DIR . '/themes'),
                'mu_plugins_dir'  => is_dir(WP_CONTENT_DIR . '/mu-plugins'),
                'last_deploy'     => file_exists(WP_CONTENT_DIR . '/.wtp_last_deploy'),
            ];

            // Wersje i meta
            $data = [
                'ok'   => ($db_ok && !in_array(false, $checks, true)),
                'php'  => PHP_VERSION,
                'wp'   => get_bloginfo('version'),
                'time' => current_time('mysql'),
                'db'   => $db_ok,
                'checks' => $checks,
                'constants' => [
                    'DISALLOW_FILE_EDIT' => defined('DISALLOW_FILE_EDIT') ? constant('DISALLOW_FILE_EDIT') : null,
                    'DISALLOW_FILE_MODS' => defined('DISALLOW_FILE_MODS') ? constant('DISALLOW_FILE_MODS') : null,
                    'AUTOMATIC_UPDATER_DISABLED' => defined('AUTOMATIC_UPDATER_DISABLED') ? constant('AUTOMATIC_UPDATER_DISABLED') : null,
                    'WP_AUTO_UPDATE_CORE' => defined('WP_AUTO_UPDATE_CORE') ? constant('WP_AUTO_UPDATE_CORE') : null,
                ],
            ];

            // Kod HTTP 200/503 zależnie od stanu
            if (!$data['ok']) {
                return new WP_REST_Response($data, 503);
            }
            return $data;
        }
    ]);
});

/**
 * 4) Minimalny nagłówek X-WTP przy admin_init (łatwiejsze debugowanie reverse proxy).
 */
add_action('admin_init', function () {
    if (!headers_sent()) {
        header('X-WTP: ok');
    }
});
