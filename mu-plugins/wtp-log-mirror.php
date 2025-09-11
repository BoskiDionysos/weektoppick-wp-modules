<?php
/**
 * Plugin Name: WTP Log Mirror -> selftest.json
 * Description: Dokleja ogon logu do selftest.json w uploads/wtp-ro/public/<site_key>/ (dozwolone przez endpoint /v1/get).
 * Author: WTP
 */
if (!defined('ABSPATH')) exit;

add_action('shutdown', function () {
    // ---- 1) Znajdź źródło logu (pierwszy istniejący) ----
    $candidates = [];
    if (defined('WP_DEBUG_LOG') && WP_DEBUG_LOG) $candidates[] = WP_DEBUG_LOG;
    $candidates[] = '/home/u493676300/debug/wp-debug.log';   // Twój docelowy
    $candidates[] = '/home/u493676300/php_errors.log';       // alternatywnie
    $candidates[] = WP_CONTENT_DIR . '/debug.log';           // fallback

    $src = null;
    foreach ($candidates as $cand) {
        if ($cand && @is_readable($cand)) { $src = $cand; break; }
    }
    if (!$src) return;

    // ---- 2) Wczytaj ogon (max ~256 KB) ----
    $TAIL_BYTES = 262144;
    $size = @filesize($src);
    $cut  = false;
    $data = '';

    $fh = @fopen($src, 'rb');
    if (!$fh) return;
    if ($size > $TAIL_BYTES) { $cut = true; fseek($fh, -1 * $TAIL_BYTES, SEEK_END); }
    $data = stream_get_contents($fh);
    fclose($fh);

    // ---- 3) Ścieżki RO ----
    $up      = wp_upload_dir();
    $basedir = rtrim($up['basedir'], '/');
    $opt     = get_option('wtp_ro_settings', []);
    $siteKey = isset($opt['site_key']) ? sanitize_text_field($opt['site_key']) : '';
    if (!$siteKey) return;

    $pubDir  = $basedir . '/wtp-ro/public/' . $siteKey;
    if (!is_dir($pubDir)) wp_mkdir_p($pubDir);
    $selftest = $pubDir . '/selftest.json';

    // ---- 4) Wczytaj istniejący selftest.json (jeśli jest) ----
    $obj = [];
    if (is_readable($selftest)) {
        $json = @file_get_contents($selftest);
        $tmp  = json_decode($json, true);
        if (is_array($tmp)) $obj = $tmp;
    }

    // ---- 5) Doklej sekcję z logiem ----
    $obj['log_tail'] = [
        'source'         => $src,
        'source_size'    => (int)$size,
        'truncated'      => $cut,
        'updated_at'     => gmdate('c'),
        'bytes'          => strlen($data),
        'content'        => $data,        // czysty tekst ogona logu
        // jeśli wolisz mniejszy JSON, można zamienić na base64:
        // 'content_b64' => base64_encode($data),
    ];

    // ---- 6) Zapisz selftest.json (pretty) ----
    @file_put_contents(
        $selftest,
        wp_json_encode($obj, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
    );
});
