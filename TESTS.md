# Tests

Register of all tests, grouped by kind and sorted by the [FEATURES.md](FEATURES.md) number each test covers. `npm test` runs everything; the guard `tests/docs-contract.sh` fails when a feature has no test entry here or when any test carries a skip marker.

The settings tests run the real `wp-config.php` of the built image with the PHP CLI of the image: `tests/wp-config-probe.php` replaces only `wp-settings.php`, the start of WordPress itself, and prints the constants and the results of the URL filters.

## Image contract

- **F1** `tests/config-contract.sh` › no_default_db_password, no_default_auth_key and the seven other keys and salts — the image sets none of these variables.
- **F1** `tests/config-contract.sh` › wp_config_no_password_fallback — `wp-config.php` has no fixed database password.
- **F2** `tests/image-contract.sh` › no sh, no bash, no busybox, no perl — the shipped image is headless.
- **F3** `tests/config-contract.sh` › debug_default, debug_false, debug_0, debug_off, debug_no — debug is off without a value and with every value that means off.
- **F3** `tests/config-contract.sh` › debug_true, debug_on, debug_yes, debug_1, debug_display — debug on, no WordPress log file.
- **F3** `tests/config-contract.sh` › debug_log, debug_all — debug on with the WordPress log file.
- **F3** `tests/config-contract.sh` › debug_log_path — a log file path switches debug on and becomes the log destination.
- **F3** `tests/config-contract.sh` › debug_unknown_value_logged — an unknown value leaves debug off and is named in the log.
- **F4** `tests/config-contract.sh` › nginx_host_default — with the default internal host, the REST URL carries the home URL and WP-Cron goes to `wordpress-nginx:8080`.
- **F4** `tests/config-contract.sh` › nginx_host_set — with `NGINX_HOST=web:8081`, the REST URL still carries the home URL and WP-Cron goes to `web:8081`.
- **F5** `tests/config-contract.sh` › disallow_file_mods_default, disallow_file_mods_true — allowed by default, forbidden with `true`.
- **F5** `tests/config-contract.sh` › disallow_file_mods_invalid_keeps_default — an invalid value keeps the default and is named in the log.
- **F6** `tests/config-contract.sh` › memory_limit_default, memory_limit_set — undefined by default, `256M` when set.
- **F6** `tests/config-contract.sh` › memory_limit_invalid_ignored — a value that is no size stays undefined and is named in the log.
- **F7** `tests/config-contract.sh` › php_limits_inherited_default, php_limits_inherited_from_environment, max_children_inherited_from_environment — `php-fpm -i` and `php-fpm -tt` of this image report the defaults of the base image and the values passed with `-e`.
