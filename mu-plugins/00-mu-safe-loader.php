<?php
/**
 * WTP Safe Loader – ultra wczesny, bez outputu!
 * - buforuj wyjście (ob_start)
 * - loguj fatale do error_log
 * - NIE drukuj nic do przeglądarki
 */
if (!defined('ABSPATH')) { exit; }

if (!defined('WTP_SAFE_LOADER')) {
    define('WTP_SAFE_LOADER', true);

    // start bardzo wczesnego bufora (czasem ratuje nagłówki)
    if (!ob_get_level()) {
        ob_start();
    }

    // głośne logowanie błędów do error_log
    @ini_set('display_errors', '0');
    @ini_set('log_errors', '1');
    error_reporting(E_ALL);

    register_shutdown_function(function () {
        $e = error_get_last();
        if ($e && in_array($e['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
            error_log('[WTP FATAL] '.$e['message'].' in '.$e['file'].':'.$e['line']);
            // nie wysyłamy HTML/echo – tylko log
        }
        // bezpieczne czyszczenie bufora – nic nie wypisujmy
        while (ob_get_level() > 0) {
            ob_end_flush(); // lub ob_end_clean() jeśli chcesz nie wypuszczać nic
        }
    });
}
