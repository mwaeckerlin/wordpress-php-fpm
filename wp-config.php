<?php
// WordPress configuration driven by environment variables (headless, no shell).

$db_name = getenv('WORDPRESS_DB_NAME') ?: 'wordpress';
$db_user = getenv('WORDPRESS_DB_USER') ?: 'wordpress';
$db_password = getenv('WORDPRESS_DB_PASSWORD') ?: 'wordpress';
$db_host_raw = getenv('WORDPRESS_DB_HOST') ?: 'mysql';
$db_port = getenv('WORDPRESS_DB_PORT') ?: '3306';
$db_host = (strpos($db_host_raw, ':') === false) ? ($db_host_raw . ':' . $db_port) : $db_host_raw;
$db_charset = getenv('WORDPRESS_DB_CHARSET') ?: 'utf8mb4';
$db_collate = getenv('WORDPRESS_DB_COLLATE') ?: '';

define('DB_NAME', $db_name);
define('DB_USER', $db_user);
define('DB_PASSWORD', $db_password);
define('DB_HOST', $db_host);
define('DB_CHARSET', $db_charset);
define('DB_COLLATE', $db_collate);

// enforce direct FS writes to avoid FTP prompts
define('FS_METHOD', 'direct');

// Disable file modifications check for language packs to allow downloads
define('DISALLOW_FILE_MODS', false);

$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

// Secrets: prefer env, otherwise load/persist from wp-secrets.php (generated on first run).
$secrets_file = __DIR__ . '/wp-secrets/wp-secrets.php';

if (file_exists($secrets_file)) {

    require_once $secrets_file;

} else {

    $secret_map = [
        'AUTH_KEY' => 'WORDPRESS_AUTH_KEY',
        'SECURE_AUTH_KEY' => 'WORDPRESS_SECURE_AUTH_KEY',
        'LOGGED_IN_KEY' => 'WORDPRESS_LOGGED_IN_KEY',
        'NONCE_KEY' => 'WORDPRESS_NONCE_KEY',
        'AUTH_SALT' => 'WORDPRESS_AUTH_SALT',
        'SECURE_AUTH_SALT' => 'WORDPRESS_SECURE_AUTH_SALT',
        'LOGGED_IN_SALT' => 'WORDPRESS_LOGGED_IN_SALT',
        'NONCE_SALT' => 'WORDPRESS_NONCE_SALT',
    ];

    foreach ($secret_map as $const => $env_var) {
        if (defined($const)) {
            continue;
        }
        $env_val = getenv($env_var);
        if ($env_val !== false && $env_val !== '') {
            define($const, $env_val);
        } else {
            $generated = base64_encode(random_bytes(48));
            define($const, $generated);
        }
    }

    $data = "<?php\n";
    foreach (array_keys($secret_map) as $const) {
        $data .= "define('" . $const . "', " . var_export(constant($const), true) . ");\n";
    }
    // best-effort persist; ignore failures if volume is read-only
    @file_put_contents($secrets_file, $data);
}

// Optional: site URLs, internal routing, and debug flags.
// NGINX_HOST: internal hostname:port for container-to-container requests (e.g., wordpress-nginx:8080)
// Used to route REST API, WP-Cron, and other self-referencing requests through Docker container network.
if ($nginx_host = getenv('NGINX_HOST')) {
    define('NGINX_INTERNAL_HOST', $nginx_host);
}

if ($home = getenv('WORDPRESS_HOME')) {
    define('WP_HOME', $home);
}
if ($siteurl = getenv('WORDPRESS_SITEURL')) {
    define('WP_SITEURL', $siteurl);
}
$debug_mode = getenv('WORDPRESS_DEBUG');
$debug_log_path = getenv('WORDPRESS_DEBUG_LOG');

$wp_debug = false;
$wp_debug_log = false;
$wp_debug_display = false;

if (!($debug_mode === false || $debug_mode === '' || strtolower($debug_mode) === 'false' || $debug_mode === '0')) {
    switch (strtolower($debug_mode)) {
        case 'true':
        case 'on':
        case 'yes':
        case '1':
            $wp_debug = true;
            break;
        case 'log':
            $wp_debug = true;
            $wp_debug_log = true;
            break;
        case 'display':
            $wp_debug = true;
            $wp_debug_display = true;
            break;
        case 'all':
            $wp_debug = true;
            $wp_debug_log = true;
            $wp_debug_display = true;
            break;
        default:
            $wp_debug = filter_var($debug_mode, FILTER_VALIDATE_BOOLEAN);
    }
}

if ($debug_log_path !== false && $debug_log_path !== '') {
    // Allow overriding the debug log destination, e.g. wp-content/logs/debug.log
    $wp_debug = true;  // Auto-enable debug when log path is explicitly set
    $wp_debug_log = $debug_log_path;
}

define('WP_DEBUG', $wp_debug);
define('WP_DEBUG_LOG', $wp_debug_log);
define('WP_DEBUG_DISPLAY', $wp_debug_display);

if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
    $_SERVER['SERVER_PORT'] = 443;
}

/* That's all, stop editing! Happy blogging. */
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';

// Internal routing filter: reroute self-calls to the container network.
// - Always reroutes localhost/127.0.0.1 to the internal host (default: wordpress-nginx:8080).
// - Also reroutes WP_HOME / WP_SITEURL targets when set.
$internal_nginx_host = getenv('NGINX_HOST');
if ($internal_nginx_host === false || $internal_nginx_host === '') {
    $internal_nginx_host = 'wordpress-nginx:8080';
}

function wp_internal_reroute_url($url, $internal_host)
{
    $parsed = parse_url($url);
    if ($parsed === false || !isset($parsed['host'])) {
        return $url;
    }

    $host = strtolower($parsed['host']);
    $scheme = isset($parsed['scheme']) ? $parsed['scheme'] : 'http';
    $path = isset($parsed['path']) ? $parsed['path'] : '';
    $query = isset($parsed['query']) ? '?' . $parsed['query'] : '';

    $should_reroute = ($host === 'localhost' || $host === '127.0.0.1');

    if (!$should_reroute) {
        $external_urls = array();
        if (defined('WP_HOME')) {
            $external_urls[] = WP_HOME;
        }
        if (defined('WP_SITEURL')) {
            $external_urls[] = WP_SITEURL;
        }

        foreach ($external_urls as $external_url) {
            if (!empty($external_url) && strpos($url, $external_url) === 0) {
                $should_reroute = true;
                break;
            }
        }
    }

    if ($should_reroute) {
        return $scheme . '://' . $internal_host . $path . $query;
    }

    return $url;
}

add_filter('http_request_args', function ($args, $url) use ($internal_nginx_host) {
    $new_url = wp_internal_reroute_url($url, $internal_nginx_host);
    if ($new_url !== $url) {
        $args['url'] = $new_url;
        $args['sslverify'] = false; // Same container network
    }
    return $args;
}, 10, 2);

// Ensure REST URLs themselves are generated with the internal host to avoid localhost targets.
add_filter('rest_url', function ($url) use ($internal_nginx_host) {
    return wp_internal_reroute_url($url, $internal_nginx_host);
});
