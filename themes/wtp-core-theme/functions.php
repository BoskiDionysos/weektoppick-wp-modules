<?php
defined('ABSPATH') || exit;

if (!defined('WTP_VERSION')) define('WTP_VERSION','1.6.4');
if (!defined('WTP_I18N_DIR')) define('WTP_I18N_DIR', get_stylesheet_directory() . '/i18n');

// Canonical parent category slugs
function wtp_parent_slugs() {
    return [
        'electronics','fashion','sports-fitness','home-garden','hobby-entertainment',
        'travel-outdoor','beauty-health','kids-toys','pets'
    ];
}

// Languages map (code => label)
function wtp_langs() {
    return ['pl'=>'Polski','en'=>'English','es'=>'Español','pt'=>'Português','cs'=>'Čeština','sk'=>'Slovenčina','de'=>'Deutsch','fr'=>'Français'];
}

// Detect & store language
function wtp_detect_lang(){
    $langs = array_keys(wtp_langs());
    if (!empty($_GET['wtp_lang']) && in_array($_GET['wtp_lang'], $langs, true)) {
        setcookie('wtp_lang', $_GET['wtp_lang'], time()+60*60*24*365, COOKIEPATH, COOKIE_DOMAIN);
        return $_GET['wtp_lang'];
    }
    if (!empty($_COOKIE['wtp_lang']) && in_array($_COOKIE['wtp_lang'], $langs, true)) return $_COOKIE['wtp_lang'];
    // Accept-Language
    $al = isset($_SERVER['HTTP_ACCEPT_LANGUAGE']) ? strtolower(sanitize_text_field($_SERVER['HTTP_ACCEPT_LANGUAGE'])) : '';
    foreach($langs as $code){
        if ($al && strpos($al, $code) === 0) {
            setcookie('wtp_lang', $code, time()+60*60*24*365, COOKIEPATH, COOKIE_DOMAIN);
            return $code;
        }
    }
    setcookie('wtp_lang', 'en', time()+60*60*24*365, COOKIEPATH, COOKIE_DOMAIN);
    return 'en';
}

// I18N: load JSON by lang
function wtp_i18n($lang){
    $file = trailingslashit(WTP_I18N_DIR) . 'terms.' . $lang . '.json';
    if (file_exists($file)) {
        $json = file_get_contents($file);
        $data = json_decode($json, true);
        if (is_array($data)) return $data;
    }
    if ($lang !== 'en') return wtp_i18n('en');
    return [];
}

// Get display name for term slug using meta name_{lang} > i18n > fallback slug
function wtp_display_name($slug, $term, $lang){
    if ($term && !is_wp_error($term)) {
        $meta = get_term_meta($term->term_id);
        $key = 'name_' . $lang;
        if (!empty($meta[$key][0])) return $meta[$key][0];
    }
    $dict = wtp_i18n($lang);
    if (isset($dict[$slug])) return $dict[$slug];
    $dictEn = wtp_i18n('en');
    return $dictEn[$slug] ?? ucwords(str_replace('-', ' ', $slug));
}

add_action('after_setup_theme', function(){
    add_theme_support('title-tag');
});

// Enqueue assets + pass data to JS
add_action('wp_enqueue_scripts', function(){
    wp_enqueue_style('wtp', get_stylesheet_uri(), [], WTP_VERSION);
    wp_enqueue_style('wtp-css', get_stylesheet_directory_uri().'/assets/css/wtp.css', [], WTP_VERSION);
    wp_enqueue_script('wtp-js', get_stylesheet_directory_uri().'/assets/js/wtp.js', [], WTP_VERSION, true);
    $lang = wtp_detect_lang();
    wp_localize_script('wtp-js', 'WTP', [
        'lang'=>$lang,
        'labels'=>wtp_langs(),
        'version'=>WTP_VERSION
    ]);
});

// Shortcode to render header bar (languages + categories + charity)
add_shortcode('wtp_header', function(){
    ob_start();
    include __DIR__ . '/templates/parts/lang-switcher.php';
    include __DIR__ . '/templates/parts/category-chips.php';
    include __DIR__ . '/templates/parts/charity-banner.php';
    return ob_get_clean();
});

// Footer build tag
add_action('wp_footer', function () {
    echo '<div class="container build">WTP Build '.esc_html(WTP_VERSION).' • commit LOCAL</div>';
});

// Selftest endpoint and file
function wtp_generate_selftest(){
    $writable = is_writable(get_stylesheet_directory());
    $lang = wtp_detect_lang();
    $cats = [];
    foreach (wtp_parent_slugs() as $slug){
        $term = get_term_by('slug', $slug, 'category');
        $children = $term ? get_terms(['taxonomy'=>'category','parent'=>$term->term_id,'hide_empty'=>false]) : [];
        $cats[] = [
            'slug'=>$slug,
            'name'=>wtp_display_name($slug,$term,$lang),
            'term_id'=>$term ? $term->term_id : null,
            'subchips_count'=>is_array($children)?count($children):0,
            'icon'=> file_exists(get_stylesheet_directory().'/assets/icons/'.$slug.'.svg') ? 'ok' : 'missing'
        ];
    }
    $out = [
        'version'=>WTP_VERSION,
        'languages'=>array_keys(wtp_langs()),
        'categories'=>$cats,
        'charity_banner'=>[
            'first_visit_position'=>'top',
            'repeat_visit_position'=>'bottom'
        ],
        'writable'=>$writable
    ];
    @file_put_contents(get_stylesheet_directory().'/selftest.txt', json_encode($out, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}
add_action('init','wtp_generate_selftest');