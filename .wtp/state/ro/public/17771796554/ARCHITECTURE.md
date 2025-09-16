# Architecture overview

## MU-plugins (overview)
Count: 19

### 00-mu-safe-loader.php
- files: 1
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: false

### wtp-canonical-redirects.php
- files: 1
- actions: 1
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: false

### wtp-canonical.php
- files: 1
- actions: 1
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: false

### wtp-deploy-guard.php
- files: 1
- actions: 3
- filters: 6
- shortcodes: 0
- rest: 1
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: false

### wtp-dev-bridge.php
- files: 1
- actions: 1
- filters: 0
- shortcodes: 0
- rest: 6
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 6
- off: false

### wtp-exporter-chunked.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-fatal-catcher.php
- files: 1
- actions: 1
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: false

### wtp-log-mirror.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-logs-export.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-patch-safe-loader-log.php
- files: 1
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: false

### wtp-patcher-plugins.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-patcher-theme.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-plugins-manifest.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-push-runner-cron.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-ro-exporter.php
- files: 1
- actions: 1
- filters: 0
- shortcodes: 0
- rest: 3
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 1
- off: false

### wtp-seo.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-tax-i18n-seo.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-theme-seo-bridge.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true

### wtp-translate.php.off
- files: 0
- actions: 0
- filters: 0
- shortcodes: 0
- rest: 0
- cpt: 0
- tax: 0
- enqueues: 0
- options: 0
- transients: 0
- crons: 0
- defines: 0
- off: true


## Plugins (overview)
Count: 0


## Active Theme (overview)
- files: 0
* actions: 0
* filters: 0
* shortcodes: 0
* rest: 0
* cpt: 0
* tax: 0
* enqueues: 0
* templates: 0


## Raw JSON (for deep dive)

### MU
```json
{"00-mu-safe-loader.php":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":1,"present":true},"wtp-canonical-redirects.php":{"actions":[{"hook":"template_redirect","cb":"function ("}],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":1,"present":true},"wtp-canonical.php":{"actions":[{"hook":"wp_head","cb":"function ("}],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":1,"present":true},"wtp-deploy-guard.php":{"actions":[{"hook":"admin_menu","cb":"function ("},{"hook":"rest_api_init","cb":"function ("},{"hook":"admin_init","cb":"function ("}],"filters":[{"hook":"filesystem_method","cb":"function ("},{"hook":"automatic_updater_disabled","cb":"'__return_true', 999"},{"hook":"auto_update_core","cb":"'__return_false', 999"},{"hook":"auto_update_plugin","cb":"'__return_false', 999"},{"hook":"auto_update_theme","cb":"'__return_false', 999"},{"hook":"plugins_api_result","cb":"function ($res"}],"shortcodes":[],"rest":[{"namespace":"wtp-ro-open/v1","route":"/health"}],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":1,"present":true},"wtp-dev-bridge.php":{"actions":[{"hook":"rest_api_init","cb":"[__CLASS__, 'register_routes']"}],"filters":[],"shortcodes":[],"rest":[{"namespace":"wtp-ro/v1","route":"/publish/theme/(?P<secret>[^/]+)"},{"namespace":"wtp-ro/v1","route":"/publish/plugins/(?P<secret>[^/]+)"},{"namespace":"wtp-ro/v1","route":"/publish/all/(?P<secret>[^/]+)"},{"namespace":"wtp-ro/v1","route":"/publish/plugins-chunked/(?P<secret>[^/]+)"},{"namespace":"wtp-ro/v1","route":"/patch/theme"},{"namespace":"wtp-ro/v1","route":"/ping"}],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":["WTP_DEV_BRIDGE_LOADED","WTP_GH_OWNER","WTP_GH_REPO","WTP_GH_BRANCH","WTP_GH_TOKEN","WTP_GH_SECRET"],"files":1,"present":true},"wtp-exporter-chunked.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-fatal-catcher.php":{"actions":[{"hook":"muplugins_loaded","cb":"function ("}],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":1,"present":true},"wtp-log-mirror.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-logs-export.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-patch-safe-loader-log.php":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":1,"present":true},"wtp-patcher-plugins.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-patcher-theme.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-plugins-manifest.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-push-runner-cron.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-ro-exporter.php":{"actions":[{"hook":"rest_api_init","cb":"function ("}],"filters":[],"shortcodes":[],"rest":[{"namespace":"wtp-ro-open/v1","route":"/ls"},{"namespace":"wtp-ro-open/v1","route":"/get"},{"namespace":"wtp-ro-open/v1","route":"/emit-logs"}],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":["WTP_RO_SITE_KEY"],"files":1,"present":true},"wtp-seo.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-tax-i18n-seo.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-theme-seo-bridge.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true},"wtp-translate.php.off":{"actions":[],"filters":[],"shortcodes":[],"rest":[],"cpt":[],"tax":[],"enqueues":[],"options":[],"transients":[],"crons":[],"defines":[],"files":0,"present":true,"off":true}}
```

### Plugins
```json
[]
```

### Theme
```json
{}
```
