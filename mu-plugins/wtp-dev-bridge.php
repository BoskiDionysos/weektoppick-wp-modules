<?php
/**
 * Plugin Name: WTP Dev Bridge — GitHub Export + Patcher (all-in-one)
 * Description: Eksport motywu i wtyczek do GitHub (z chunkowaniem) + patch motywu z theme-bundle.json (RAW). Bez kolizji stałych.
 * Version: 4.0.0
 */
if (!defined('ABSPATH')) exit;

// ─────────────────────────────────────────────────────────────
// GLOBAL GUARD: ładuj tylko raz (eliminuje duplikaty w logach)
// ─────────────────────────────────────────────────────────────
if (defined('WTP_DEV_BRIDGE_LOADED')) return;
define('WTP_DEV_BRIDGE_LOADED', true);

// ─────────────────────────────────────────────────────────────
// WYMAGANE W wp-config.php  (NIE definiujemy tu!)
// ─  define('WTP_GH_OWNER',  'BoskiDionysos');
// ─  define('WTP_GH_REPO',   'weektoppick-wp-modules');
// ─  define('WTP_GH_BRANCH', 'main');               // opcjonalnie
// ─  define('WTP_GH_TOKEN',  'ghp_xxx');            // repo:contents write
// ─  define('WTP_GH_SECRET', 'super_tajny_sekret'); // do REST
// ─────────────────────────────────────────────────────────────
$__need = ['WTP_GH_OWNER','WTP_GH_REPO','WTP_GH_TOKEN','WTP_GH_SECRET'];
foreach ($__need as $__c) { if (!defined($__c)) { error_log("[WTP Bridge] Missing constant $__c"); return; } }

// ============================================================================
// KLASA – cała logika w środku (brak globalnych const → brak kolizji)
// ============================================================================
if (!class_exists('WTP_Dev_Bridge')):

final class WTP_Dev_Bridge {

    // Konfiguracja (trzymamy w właściwościach – nie ma redefinicji)
    private static array $allowedExt     = ['php','css','js','json','svg','txt','md','html','po','mo'];
    private static string $excludeRx     = '#(?:^|/)(node_modules|vendor|\.git|\.svn|\.github|tests?|bin|dist|cache)(/|$)#i';
    private static string $excludeFileRx = '#\.(map|lock|min\.map|ico|woff2?|ttf|eot)$#i';
    private static int    $chunkTarget   = 4_500_000; // ~4.5 MB (poniżej 5 MB limitów)
    private static string $themeTarget   = 'theme-bundle.json';
    private static string $pluginsTarget = 'plugins-bundle.json';
    private static string $pluginsIndex  = 'plugins-index.json';
    private static string $chunkBase     = 'plugins-bundle';

    // ─────────────────────────────────────────────────────────
    // ROUTES
    // ─────────────────────────────────────────────────────────
    public static function boot() : void {
        add_action('rest_api_init', [__CLASS__, 'register_routes']);
    }

    public static function register_routes() : void {

        // publish/theme/{secret}
        register_rest_route('wtp-ro/v1', '/publish/theme/(?P<secret>[^/]+)', [
            'methods'  => 'GET',
            'permission_callback' => '__return_true',
            'callback' => function(\WP_REST_Request $req) {
                if (!self::auth_secret_path($req)) return self::err(403,'forbidden');
                $bundle = self::collect_theme();
                if (!$bundle) return self::err(500,'empty-theme');
                $res = self::push_to_github($bundle, self::$themeTarget, 'Update theme-bundle.json (publish)');
                return self::answer($res);
            }
        ]);

        // publish/plugins/{secret}
        register_rest_route('wtp-ro/v1', '/publish/plugins/(?P<secret>[^/]+)', [
            'methods'  => 'GET',
            'permission_callback' => '__return_true',
            'callback' => function(\WP_REST_Request $req) {
                if (!self::auth_secret_path($req)) return self::err(403,'forbidden');
                $bundle = self::collect_plugins_full();
                if (!$bundle) return self::err(500,'empty-plugins');
                $res = self::push_to_github($bundle, self::$pluginsTarget, 'Update plugins-bundle.json (publish)');
                return self::answer($res);
            }
        ]);

        // publish/all/{secret}
        register_rest_route('wtp-ro/v1', '/publish/all/(?P<secret>[^/]+)', [
            'methods'  => 'GET',
            'permission_callback' => '__return_true',
            'callback' => function(\WP_REST_Request $req) {
                if (!self::auth_secret_path($req)) return self::err(403,'forbidden');

                $out = [];

                $theme = self::collect_theme();
                if ($theme) {
                    $r1 = self::push_to_github($theme, self::$themeTarget, 'Update theme-bundle.json (publish-all)');
                    $out['theme'] = self::res_map($r1);
                } else $out['theme'] = ['ok'=>false,'error'=>'empty-theme'];

                $plugins = self::collect_plugins_full();
                if ($plugins) {
                    $r2 = self::push_to_github($plugins, self::$pluginsTarget, 'Update plugins-bundle.json (publish-all)');
                    $out['plugins'] = self::res_map($r2);
                } else $out['plugins'] = ['ok'=>false,'error'=>'empty-plugins'];

                $ok = ($out['theme']['ok']??false) || ($out['plugins']['ok']??false);
                return new \WP_REST_Response(['ok'=>$ok]+$out, $ok?200:500);
            }
        ]);

        // publish/plugins-chunked/{secret}
        register_rest_route('wtp-ro/v1', '/publish/plugins-chunked/(?P<secret>[^/]+)', [
            'methods'  => 'GET',
            'permission_callback' => '__return_true',
            'callback' => function(\WP_REST_Request $req) {
                if (!self::auth_secret_path($req)) return self::err(403,'forbidden');
                $bundle = self::collect_plugins_full();
                if (!$bundle) return self::err(500,'empty-plugins');

                $chunks = self::chunk_map($bundle, self::$chunkTarget);
                if (!$chunks) return self::err(500,'chunking-failed');

                $push = self::push_chunks_and_index($chunks);
                if (is_wp_error($push)) return self::err(500, $push->get_error_message());
                return new \WP_REST_Response(['ok'=>true]+$push, 200);
            }
        ]);

        // patch/theme?key=SECRET&url=RAW_JSON&dry=0|1
        register_rest_route('wtp-ro/v1', '/patch/theme', [
            'methods'  => 'GET',
            'permission_callback' => '__return_true',
            'callback' => function(\WP_REST_Request $req) {
                $key = (string)$req->get_param('key');
                if (!$key || $key !== constant('WTP_GH_SECRET')) return self::err(403,'forbidden');

                $url = trim((string)$req->get_param('url'));
                if ($url === '') return self::err(400,'missing-url');

                $dry = (string)$req->get_param('dry');
                $dry = ($dry === '1' || strtolower($dry) === 'true' || $dry === 'on') ? true : false;

                $json = self::http('GET', $url, null, null, 25);
                if ($json['code'] !== 200 || !is_array($json['body_raw'])) {
                    return self::err(502, 'fetch-failed');
                }
                $map = $json['body_raw']; // mapa "theme/relpath" => content

                $themeDir = wp_normalize_path(get_stylesheet_directory());
                $updated = []; $created = []; $skipped = []; $errors = [];

                foreach ($map as $k => $v) {
                    if (strpos($k, 'theme/') !== 0) { $skipped[] = $k; continue; }
                    $rel = ltrim(substr($k, 6), '/'); // po "theme/"
                    if ($rel === '') { $skipped[] = $k; continue; }

                    $target = $themeDir . '/' . $rel;
                    $dir = dirname($target);
                    if (!is_dir($dir)) {
                        if (!$dry) @wp_mkdir_p($dir);
                        if (!is_dir($dir)) { $errors[] = $rel; continue; }
                    }
                    $exists = file_exists($target);
                    if (!$dry) {
                        $ok = @file_put_contents($target, $v);
                        if ($ok === false) { $errors[] = $rel; continue; }
                    }
                    if ($exists) $updated[] = $rel; else $created[] = $rel;
                }

                return new \WP_REST_Response([
                    'ok'      => empty($errors),
                    'dry_run' => $dry,
                    'source'  => $url,
                    'theme'   => basename($themeDir),
                    'created' => $created,
                    'updated' => $updated,
                    'skipped' => $skipped,
                    'errors'  => $errors,
                ], empty($errors) ? 200 : 500);
            }
        ]);

        // proste: ping/selftest (bez sekretu)
        register_rest_route('wtp-ro/v1', '/ping', [
            'methods'  => 'GET',
            'permission_callback' => '__return_true',
            'callback' => fn() => new \WP_REST_Response(['ok'=>true,'ts'=>time()], 200)
        ]);
    }

    // ─────────────────────────────────────────────────────────
    // AUTH helpers
    // ─────────────────────────────────────────────────────────
    private static function auth_secret_path(\WP_REST_Request $req) : bool {
        $sec = (string)$req->get_param('secret');
        return ($sec !== '' && $sec === constant('WTP_GH_SECRET'));
    }

    // ─────────────────────────────────────────────────────────
    // COLLECTORS
    // ─────────────────────────────────────────────────────────
    private static function collect_theme() : array {
        $base = wp_normalize_path( get_stylesheet_directory() );
        return self::collect_from_base($base, 'theme');
    }

    private static function collect_plugins_full() : array {
        $out = [];
        $plugins = wp_normalize_path( WP_PLUGIN_DIR );
        if (is_dir($plugins)) $out += self::collect_from_base($plugins, 'plugins');

        $mu = wp_normalize_path( WPMU_PLUGIN_DIR );
        if (is_dir($mu) && $mu !== $plugins) $out += self::collect_from_base($mu, 'mu-plugins');

        return $out;
    }

    private static function collect_from_base(string $base, string $prefix) : array {
        $rii = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($base, \FilesystemIterator::SKIP_DOTS));
        $out = [];
        foreach ($rii as $spl) {
            /** @var \SplFileInfo $spl */
            if (!$spl->isFile()) continue;

            $path = wp_normalize_path($spl->getPathname());
            $rel  = ltrim(str_replace($base, '', $path), '/');

            if (preg_match(self::$excludeRx, $rel))     continue;
            if (preg_match(self::$excludeFileRx, $rel)) continue;

            $ext = strtolower(pathinfo($rel, PATHINFO_EXTENSION));
            if (!in_array($ext, self::$allowedExt, true)) continue;

            $content = @file_get_contents($path);
            if ($content === false) continue;

            $key = trim($prefix,'/').'/'.$rel;
            $out[$key] = $content;
        }
        return $out;
    }

    // ─────────────────────────────────────────────────────────
    // CHUNKING
    // ─────────────────────────────────────────────────────────
    private static function chunk_map(array $map, int $targetBytes) : array {
        $chunks = []; $current = []; $approx = 2; // {}
        foreach ($map as $k => $v) {
            $entry = [$k => $v];
            $ej = json_encode($entry, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE);
            $sz = strlen($ej) + 1;
            if ($approx + $sz > $targetBytes && !empty($current)) {
                $chunks[] = $current; $current = []; $approx = 2;
            }
            $current[$k] = $v; $approx += $sz;
        }
        if (!empty($current)) $chunks[] = $current;
        return $chunks;
    }

    // ─────────────────────────────────────────────────────────
    // GITHUB PUSH (single file)
    // ─────────────────────────────────────────────────────────
    private static function push_to_github(array $bundle, string $target, string $msg) {
        if (empty($bundle)) return new \WP_Error('wtp_empty','Empty bundle');
        $payload = json_encode($bundle, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT|JSON_INVALID_UTF8_SUBSTITUTE);
        if ($payload === false) return new \WP_Error('wtp_json','json_encode failed');

        $owner  = constant('WTP_GH_OWNER');
        $repo   = constant('WTP_GH_REPO');
        $branch = defined('WTP_GH_BRANCH') ? constant('WTP_GH_BRANCH') : 'main';
        $token  = constant('WTP_GH_TOKEN');

        $api  = "https://api.github.com/repos/{$owner}/{$repo}/contents/{$target}";
        $sha  = null;
        $get  = self::http('GET', $api.'?ref='.rawurlencode($branch), $token, null, 25);
        if ($get['code'] === 200 && !empty($get['body']['sha'])) $sha = $get['body']['sha'];

        $body = ['message'=>$msg,'content'=>base64_encode($payload),'branch'=>$branch];
        if ($sha) $body['sha'] = $sha;

        $put = self::http('PUT', $api, $token, $body, 30);
        if ($put['code'] >= 300) {
            return new \WP_Error('wtp_github_put', 'GitHub PUT error '.$put['code'].': '.json_encode($put['body']));
        }

        $raw = "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/{$target}";
        return ['raw_url'=>$raw,'commit'=>$put['body']['commit']['sha'] ?? null];
    }

    // ─────────────────────────────────────────────────────────
    // GITHUB PUSH (chunks + index)
    // ─────────────────────────────────────────────────────────
    private static function push_chunks_and_index(array $chunks) {
        $owner  = constant('WTP_GH_OWNER');
        $repo   = constant('WTP_GH_REPO');
        $branch = defined('WTP_GH_BRANCH') ? constant('WTP_GH_BRANCH') : 'main';
        $token  = constant('WTP_GH_TOKEN');

        $pushed = [];
        foreach ($chunks as $i => $map) {
            $payload = json_encode($map, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT|JSON_INVALID_UTF8_SUBSTITUTE);
            $path    = sprintf('%s_%03d.json', self::$chunkBase, $i);
            $res     = self::gh_put_file($owner,$repo,$branch,$token,$path,$payload,'Update '.$path.' (chunk)');
            if ($res['code'] >= 300) {
                return new \WP_Error('wtp_github_put', 'GitHub PUT error '.$res['code'].': '.json_encode($res['body']));
            }
            $pushed[] = [
                'path' => $path,
                'size' => strlen($payload),
                'sha1' => sha1($payload),
                'raw'  => "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/{$path}",
            ];
        }

        $index = [
            'version'       => 1,
            'generated_at'  => time(),
            'total_chunks'  => count($pushed),
            'chunks'        => $pushed,
        ];
        $idxPayload = json_encode($index, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);
        $idxRes     = self::gh_put_file($owner,$repo,$branch,$token,self::$pluginsIndex,$idxPayload,'Update '.self::$pluginsIndex.' (index)');
        if ($idxRes['code'] >= 300) {
            return new \WP_Error('wtp_github_put', 'GitHub PUT index error '.$idxRes['code'].': '.json_encode($idxRes['body']));
        }

        return [
            'index_raw_url' => "https://raw.githubusercontent.com/{$owner}/{$repo}/{$branch}/".self::$pluginsIndex,
            'chunks'        => $pushed,
        ];
    }

    private static function gh_put_file($owner,$repo,$branch,$token,$path,$content,$message) {
        $api = "https://api.github.com/repos/{$owner}/{$repo}/contents/{$path}";
        $sha = null;
        $get = self::http('GET', $api.'?ref='.rawurlencode($branch), $token, null, 25);
        if ($get['code'] === 200 && !empty($get['body']['sha'])) $sha = $get['body']['sha'];

        $body = ['message'=>$message,'content'=>base64_encode($content),'branch'=>$branch];
        if ($sha) $body['sha'] = $sha;
        return self::http('PUT', $api, $token, $body, 30);
    }

    // ─────────────────────────────────────────────────────────
    // HTTP helper (WP)
    // ─────────────────────────────────────────────────────────
    private static function http(string $method, string $url, ?string $token, $json, int $timeout = 20) : array {
        $args = [
            'method'  => $method,
            'headers' => [
                'User-Agent' => 'WTP-Dev-Bridge',
                'Accept'     => 'application/json',
            ],
            'timeout' => $timeout,
        ];
        if ($token) $args['headers']['Authorization'] = 'token '.$token;
        if ($json !== null) {
            $args['headers']['Content-Type'] = 'application/json';
            $args['body'] = is_string($json) ? $json : json_encode($json);
        }
        $res  = wp_remote_request($url, $args);
        $code = wp_remote_retrieve_response_code($res);
        $body = wp_remote_retrieve_body($res);

        // spróbuj JSON; jeśli nie wychodzi – zwróć raw
        $decoded = json_decode($body, true);
        return [
            'code'     => $code,
            'body'     => is_array($decoded) ? $decoded : null,
            'body_raw' => is_array($decoded) ? $decoded : null,
            'text'     => is_array($decoded) ? null : $body,
        ];
    }

    // ─────────────────────────────────────────────────────────
    // Response helpers
    // ─────────────────────────────────────────────────────────
    private static function err(int $code, string $msg) {
        return new \WP_REST_Response(['ok'=>false,'error'=>$msg], $code);
    }
    private static function answer($res) {
        if (is_wp_error($res)) return self::err(500, $res->get_error_message());
        return new \WP_REST_Response(['ok'=>true]+$res, 200);
    }
    private static function res_map($res) : array {
        return is_wp_error($res) ? ['ok'=>false,'error'=>$res->get_error_message()] : ['ok'=>true]+$res;
    }
}

WTP_Dev_Bridge::boot();

endif; // class exists
