<?php
declare(strict_types=1);

/**
 * WTP: fatal catcher (MU-plugin)
 * - nic NIE wypisuje, tylko loguje do error_log
 * - zero BOM/whitespace’u na początku/końcu
 */

@ini_set('display_errors', '0');
@ini_set('log_errors', '1');

if (!function_exists('wtp_register_fatal_catcher')) {
    function wtp_register_fatal_catcher(): void {
        register_shutdown_function(static function (): void {
            $e = error_get_last();
            if ($e && in_array($e['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
                error_log(sprintf(
                    '[WTP_FATAL] %s in %s:%d',
                    $e['message'] ?? 'unknown',
                    $e['file'] ?? 'unknown',
                    $e['line'] ?? 0
                ));
            }
        });
    }
}

wtp_register_fatal_catcher();
