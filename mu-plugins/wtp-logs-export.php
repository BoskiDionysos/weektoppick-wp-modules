<?php
/**
 * WTP Logs Export (MU) - harden
 * Zrzuca tail logów do uploads/wtp-ro/public/<site_key>/logs i zwraca tekst "Export OK".
 */
if (!defined('ABSPATH')) { /* nadal pozwól działać, ale bez WP helperów */ }

(function () {
    // ---- KONFIG ----
    $site_key     = '5Depft8Y9LU0t6Sv';
    $wp_debug_src = '/home/u493676300/debug/wp-debug.log';
    $php_err_src  = '/home/u493676300/php_errors.log';
    $tail_bytes   = 256 * 1024;
    $throttle_s   = 60;

    // Tylko gdy param =1
    if (!isset($_GET['wtp-export-logs']) || $_GET['wtp-export-logs'] !== '1') {
        // ale jeśli WordPress już stoi, spróbujemy zarejestrować hook
        if (function_exists('add_action')) {
            add_action('muplugins_loaded', __FUNCTION__);
        }
        return;
    }

    // Wylicz bazę docelową bezpiecznie, z lub bez WP
    $basedir = null;
    if (function_exists('wp_get_upload_dir')) {
        $u = wp_get_upload_dir();
        if (!empty($u['basedir'])) $basedir = $u['basedir'];
    }
    if (!$basedir && defined('WP_CONTENT_DIR')) {
        $basedir = rtrim(WP_CONTENT_DIR, '/').'/uploads';
    }
    if (!$basedir) {
        $basedir = __DIR__ . '/../uploads'; // awaryjnie
    }

    $base = rtrim($basedir, '/').'/wtp-ro/public/'.$site_key.'/logs';
    if (!is_dir($base)) {
        @mkdir($base, 0775, true);
    }

    // throttle
    $flag = $base.'/.last_export';
    $now  = time();
    $last = @is_file($flag) ? (int) @file_get_contents($flag) : 0;
    if (($now - $last) < $throttle_s) {
        @header('Content-Type: text/plain; charset=utf-8');
        echo "Export skipped (throttle)\n";
        exit;
    }

    // prosty tail
    $tail = function ($path, $bytes) {
        if (!@is_file($path) || !@is_readable($path)) return '';
        $size = @filesize($path);
        if ($size === false || $size === 0) return '';
        $start = max(0, $size - $bytes);
        $fh = @fopen($path, 'rb'); if (!$fh) return '';
        if ($start > 0) fseek($fh, $start);
        $data = stream_get_contents($fh);
        fclose($fh);
        if ($start > 0 && ($p = strpos($data, "\n")) !== false) $data = substr($data, $p+1);
        return $data;
    };

    $wrote = [];

    $wp_tail = $tail($wp_debug_src, $tail_bytes);
    if ($wp_tail !== '') {
        $dst = $base.'/wp-debug-latest.txt';
        @file_put_contents($dst, "=== wp-debug @ ".gmdate('c')." ===\n".$wp_tail);
        $wrote[] = basename($dst);
    }

    $php_tail = $tail($php_err_src, $tail_bytes);
    if ($php_tail !== '') {
        $dst = $base.'/php-errors-latest.txt';
        @file_put_contents($dst, "=== php_errors @ ".gmdate('c')." ===\n".$php_tail);
        $wrote[] = basename($dst);
    }

    @file_put_contents($flag, (string)$now);

    @header('Content-Type: text/plain; charset=utf-8');
    echo "Export OK\nBase: $base\n";
    foreach ($wrote as $f) echo " - $f\n";
    if (!$wrote) echo "No source logs had data\n";
    exit;
})();
