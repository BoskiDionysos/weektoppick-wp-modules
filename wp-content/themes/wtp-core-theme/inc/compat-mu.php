<?php
defined('ABSPATH') || exit;

/**
 * Adapter: use MU-plugin functions if available. Otherwise fallback.
 */

// Canonical
add_action('wp_head', function () {
    if (function_exists('wtp_mu_canonical')) {
        echo wtp_mu_canonical();
    } elseif (get_option('wtp_seo_fallback', true)) {
        // fallback: simple canonical
        echo '<link rel="canonical" href="' . esc_url(get_permalink()) . '" />' . PHP_EOL;
    }
}, 1);

// Hreflang
add_action('wp_head', function () {
    if (function_exists('wtp_mu_hreflang')) {
        echo wtp_mu_hreflang();
    } elseif (get_option('wtp_seo_fallback', true)) {
        $lang = get_locale();
        echo '<link rel="alternate" hrefrelang="' . esc_attr($lang) . '" href="' . esc__url(get_permalink()) . '" />' . PHP_EOL;
    }
}, 1);
