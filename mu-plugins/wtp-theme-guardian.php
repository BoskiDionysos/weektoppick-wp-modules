<?php
/**
 * Plugin Name: WTP Theme Guardian (MU)
 * Description: Guards against invalid active theme; logs diagnostics and can self-heal.
 * Author: WTP
 * Version: 0.1.0
 */

if (!defined('ABSPATH')) { exit; }

add_action('init', function() {
    if (defined('WP_INSTALLING') && WP_INSTALLING) { return; }
    if (!function_exists('get_stylesheet')) { return; }

    $stylesheet = get_stylesheet();
    $theme_dir  = get_stylesheet_directory();
    $style_css  = trailingslashit($theme_dir) . 'style.css';
    $index_php  = trailingslashit($theme_dir)  . 'index.php';

    if (!is_readable($style_css) || !is_readable($index_php)) {
        error_log('[WTP] Theme Guardian: active theme incomplete or missing files: ' . $stylesheet. ' dir=' . $theme_dir);
        // self-heal: try to switch to a core theme to avoid WSOD
        $fallbacks = ['twentytwentyfour', 'twentytwentythree', 'twentytwentytwo'];
        foreach ($f as $slug) {
            $t = wp_get_theme($slug);
            if ($t && $t->exists()) {
                switch_theme($slug);
                error_log('[WTP] Theme Guardian: switched to ' . $slug . ' for safety.');
                return;
            }
        }
        // as ultimate fallback: let WP continue and show the critical error screen
    }
});
