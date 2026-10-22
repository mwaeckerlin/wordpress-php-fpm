<?php
// Loads /app/wp-config.php of the image with an empty wp-settings.php and prints what it defines.
// Usage: docker run -i --rm --entrypoint /usr/bin/php [-e VAR=value ...] IMAGE < tests/wp-config-probe.php

$probe_root = sys_get_temp_dir() . '/wp-probe/';
@mkdir($probe_root);
file_put_contents($probe_root . 'wp-settings.php', "<?php\n");
define('ABSPATH', $probe_root);

$probe_filters = [];

function add_filter($tag, $callback, $priority = 10, $accepted_args = 1)
{
    $GLOBALS['probe_filters'][$tag][$priority][] = [$callback, $accepted_args];
}

function apply_filters($tag, $value, ...$args)
{
    $by_priority = $GLOBALS['probe_filters'][$tag] ?? [];
    ksort($by_priority);
    foreach ($by_priority as $callbacks) {
        foreach ($callbacks as [$callback, $accepted_args]) {
            $value = call_user_func_array($callback, array_slice(array_merge([$value], $args), 0, $accepted_args));
        }
    }
    return $value;
}

require '/app/wp-config.php';

$home = defined('WP_HOME') && WP_HOME !== '' ? WP_HOME : 'http://localhost';
$request = apply_filters('http_request_args', [], 'http://localhost/wp-cron.php');

echo 'WP_DEBUG=' . var_export(WP_DEBUG, true) . "\n";
echo 'WP_DEBUG_LOG=' . var_export(WP_DEBUG_LOG, true) . "\n";
echo 'DISALLOW_FILE_MODS=' . var_export(DISALLOW_FILE_MODS, true) . "\n";
echo 'WP_MEMORY_LIMIT=' . (defined('WP_MEMORY_LIMIT') ? var_export(WP_MEMORY_LIMIT, true) : 'undefined') . "\n";
echo 'rest_url=' . apply_filters('rest_url', rtrim($home, '/') . '/wp-json/') . "\n";
echo 'self_call=' . ($request['url'] ?? 'http://localhost/wp-cron.php') . "\n";
