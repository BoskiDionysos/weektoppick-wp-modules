<?php
/**
 * Plugin Name: WTP Canonical Redirects
 * Description: 301 z /?p=ID na kanoniczny permalink; usuwa śmieciowe parametry.
 */

if (!defined('ABSPATH')) exit;

add_action('template_redirect', function () {
    // 1) /?p=ID -> permalink
    if (isset($_GET['p']) && is_numeric($_GET['p'])) {
        $id = (int) $_GET['p'];
        $url = get_permalink($id);
        if ($url && !is_wp_error($url)) {
            wp_redirect($url, 301);
            exit;
        }
    }

    // 2) jeśli to feed na stronie, przekieruj na stronę bez /feed/
    if (is_feed()) {
        $url = home_url(add_query_arg([]));
        if ($url) {
            wp_redirect($url, 301);
            exit;
        }
    }
}, 1);
