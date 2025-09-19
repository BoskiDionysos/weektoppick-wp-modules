<?php
/* Auto-rendered by GitHub Actions, do not edit on server */

define('DB_NAME',     '${WP_DB_NAME}');
define('DB_USER',     '${WP_DB_USER}');
define('DB_PASSWORD', '${WP_DB_PASSWORD}');
define('DB_HOST',     '${WP_DB_HOST}');
define('DB_CHARSET',  'utf8');
define('DB_COLLATE',  '');

$table_prefix = '${WP_TABLE_PREFIX:-wp_}';

define('WP_HOME',    '${WP_HOME_URL}');
define('WP_SITEURL', '${WP_SITEURL}');

/* Cache flag kept if needed by LSCache */
if (!defined('WP_CACHE')) define('WP_CACHE', true);

/* Debug – domyślnie OFF na produkcji; możesz podmieniać tymczasowo */
if (!defined('WP_DEBUG')) define('WP_DEBUG', false);
if (!defined('WP_DEBUG_DISPLAY')) define('WP_DEBUG_DISPLAY', false);
@ini_set('display_errors', 0);

/* Zewnętrzny log – jeśli chcesz, możesz dopisać ścieżki przez ini_set w MU-pluginie */

/* Bezpieczeństwo */
if (!defined('DISALLOW_FILE_EDIT')) define('DISALLOW_FILE_EDIT', true);
if (!defined('FORCE_SSL_ADMIN')) define('FORCE_SSL_ADMIN', true);

/* Wydajność */
if (!defined('DISABLE_WP_CRON')) define('DISABLE_WP_CRON', false);
if (!defined('WP_MEMORY_LIMIT')) define('WP_MEMORY_LIMIT', '512M');

/* --- SALTS zostaną docięte automatycznie poniżej przez workflow --- */

/* Absolute path to the WordPress directory. */
if ( ! defined('ABSPATH') ) {
  define('ABSPATH', __DIR__ . '/');
}

/* Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
