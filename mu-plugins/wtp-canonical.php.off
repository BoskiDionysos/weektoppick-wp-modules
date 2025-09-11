<?php
/**
 * Plugin Name: WTP Canonical + Robots
 * Description: Ustala <link rel="canonical"> i dodaje noindex dla feed/search/404. Działa jako MU-plugin.
 */
if (!defined('ABSPATH')) exit;

add_action('wp_head', function () {
    // Noindex dla stron, których nie chcemy w indeksie
    if (is_feed() || is_search() || is_404()) {
        echo "<meta name=\"robots\" content=\"noindex,follow\" />\n";
        return;
    }

    // Wyznacz adres kanoniczny
    $url = null;

    if (is_singular()) {
        $url = get_permalink();
    } elseif (is_home() || is_front_page()) {
        $url = home_url('/');
    } elseif (is_category() || is_tag() || is_tax()) {
        $term = get_queried_object();
        if ($term && !is_wp_error($term)) {
            $url = get_term_link($term);
        }
    } elseif (is_post_type_archive()) {
        $pt = get_query_var('post_type');
        if ($pt) {
            $url = get_post_type_archive_link($pt);
        }
    } elseif (is_author()) {
        $author = get_queried_object();
        if ($author && isset($author->ID)) {
            $url = get_author_posts_url($author->ID);
        }
    } elseif (is_date() || is_archive()) {
        // Fallback dla innych archiwów
        global $wp;
        $req = isset($wp->request) ? $wp->request : '';
        $url = home_url(user_trailingslashit($req));
    }

    if (!$url) return;

    // Obsługa paginacji (kanoniczny z /page/N/)
    $paged = (int) get_query_var('paged');
    if ($paged > 1) {
        $url = trailingslashit($url) . user_trailingslashit('page/' . $paged, 'paged');
    }

    // Usuń śmieciowe parametry z kanonicznego
    $url = remove_query_arg(array(
        'utm_source','utm_medium','utm_campaign','utm_term','utm_content',
        'gclid','fbclid','_ga','_gl'
    ), $url);

    // Wypluj canonical
    $url = esc_url($url);
    if ($url) {
        echo '<link rel="canonical" href="' . $url . "\" />\n";
    }
}, 1);
