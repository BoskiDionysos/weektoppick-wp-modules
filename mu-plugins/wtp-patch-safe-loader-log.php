<?php
/**
 * Plugin Name: WTP Patch – MU Log Probe
 * Description: Minimalny MU-plugin dorzucany łatką; zapisuje wpis do /home/u493676300/debug/patch-test.log
 * Author: WTP Bot
 * Version: 0.1.0
 */

// Ładujemy bardzo wcześnie – mu-plugins są autoload.
if (!function_exists('wtp_patch_mu_log_probe')) {
    function wtp_patch_mu_log_probe() {
        $file = '/home/u493676300/debug/patch-test.log';
        $line = date('c') . " – MU patch probe OK\n";
        $dir  = dirname($file);
        if (!is_dir($dir)) {
            @mkdir($dir, 0755, true);
        }
        if (is_dir($dir) && is_writable($dir)) {
            @file_put_contents($file, $line, FILE_APPEND);
        }
    }
    wtp_patch_mu_log_probe();
}
