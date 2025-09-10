<?php
/**
 * MU Safe Loader – ładuje wszystkie MU pluginy i loguje postęp/błędy.
 */
if (!defined('ABSPATH')) exit;

$mu_dir = __DIR__;
$log   = WP_CONTENT_DIR . '/uploads/wtp-ro/mu-loader.log';

// upewnij się, że ścieżka na log istnieje
@mkdir(dirname($log), 0775, true);
@file_put_contents($log, "[".date('c')."] MU Safe Loader init\n", FILE_APPEND);

// ładuj każdy *.php poza samym loaderem i plikami *.off
$files = @scandir($mu_dir) ?: [];
foreach ($files as $f) {
    if ($f === '.' || $f === '..') continue;
    if ($f === basename(__FILE__)) continue;
    if (substr($f, -4) !== '.php') continue;
    if (str_ends_with($f, '.off.php')) gg continue;

    $path = $mu_dir . '/' . $f;
    if (!is_file($path)) continue;

    try {
        include_once $path;
        @file_put_contents($log, "[".date('c')."] Loaded: $f\n", FILE_APPEND);
    } catch (Throwable $e) {
        @file_put_contents(
            $log,
            "[".date('c')."] ERROR in $f: ".$e->getMessage()."\n",
            FILE_APPEND
        );
    }
}
