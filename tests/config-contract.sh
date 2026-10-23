#!/usr/bin/env bash
# Config contract: the image ships no secret.
#
# The keys and salts sign the login cookies; a value baked into the image is
# the same in every installation, so whoever reads this repository can forge a
# login. wp-config.php generates random ones on the first start when the
# variables are unset, and the image must leave them unset. The database
# password has no default either: without WORDPRESS_DB_PASSWORD the connection
# fails at once instead of coming up on a publicly known password.
#
# The settings an operator may change are environment variables with defaults:
# tests/wp-config-probe.php loads the real wp-config.php of the image with the
# PHP CLI and prints what it defines, once with the defaults and once per value.
#
# The php-fpm pool keeps session upload progress and fatal error backtraces off
# and locked, as mwaeckerlin/php-fpm sets them.
#
# Usage: tests/config-contract.sh IMAGE

set -uo pipefail

IMAGE="${1:?usage: tests/config-contract.sh IMAGE}"
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

echo "==> Config contract: no secret in the image"

if ! docker image inspect "${IMAGE}" > /dev/null 2>&1; then
    _fail "${IMAGE}_image_exists" "image not built — run 'npm run build' first"
else
    ENVIRONMENT=$(docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${IMAGE}")
    for name in DB_PASSWORD AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        if grep -q "^WORDPRESS_${name}=" <<< "${ENVIRONMENT}"; then
            _fail "no_default_${name,,}" "the image sets WORDPRESS_${name}"
        else
            _pass "no_default_${name,,}"
        fi
    done
fi

if grep -q "getenv('WORDPRESS_DB_PASSWORD') ?:" wp-config.php; then
    _fail "wp_config_no_password_fallback" "wp-config.php falls back to a fixed database password"
else
    _pass "wp_config_no_password_fallback"
fi

echo "==> Config contract: settings from the environment"

_probe() {
    docker run -i --rm --pull=never --entrypoint /usr/bin/php "$@" "${IMAGE}" < tests/wp-config-probe.php 2>&1
}

# _expect NAME "LINE..." [-e VAR=value ...]: every expected line appears in the probe output
_expect() {
    local name="$1" expected="$2" output line
    shift 2
    output=$(_probe "$@")
    while IFS= read -r line; do
        if ! grep -qxF "${line}" <<< "${output}"; then
            _fail "${name}" "expected '${line}', got: $(echo ${output})"
            return
        fi
    done <<< "${expected}"
    _pass "${name}"
}

if docker image inspect "${IMAGE}" > /dev/null 2>&1; then
    _expect debug_default $'WP_DEBUG=false\nWP_DEBUG_LOG=false'
    _expect debug_false $'WP_DEBUG=false\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=false
    _expect debug_0 $'WP_DEBUG=false\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=0
    _expect debug_off $'WP_DEBUG=false\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=off
    _expect debug_no $'WP_DEBUG=false\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=no
    _expect debug_true $'WP_DEBUG=true\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=true
    _expect debug_on $'WP_DEBUG=true\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=on
    _expect debug_yes $'WP_DEBUG=true\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=yes
    _expect debug_1 $'WP_DEBUG=true\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=1
    _expect debug_display $'WP_DEBUG=true\nWP_DEBUG_LOG=false' -e WORDPRESS_DEBUG=display
    _expect debug_log $'WP_DEBUG=true\nWP_DEBUG_LOG=true' -e WORDPRESS_DEBUG=log
    _expect debug_all $'WP_DEBUG=true\nWP_DEBUG_LOG=true' -e WORDPRESS_DEBUG=all
    _expect debug_log_path $'WP_DEBUG=true\nWP_DEBUG_LOG=\'/app/wp-content/logs/debug.log\'' -e WORDPRESS_DEBUG_LOG=/app/wp-content/logs/debug.log
    _expect debug_unknown_value_logged $'WP_DEBUG=false\nWORDPRESS_DEBUG=verbose is neither true nor false, using false' -e WORDPRESS_DEBUG=verbose

    _expect disallow_file_mods_default 'DISALLOW_FILE_MODS=false'
    _expect disallow_file_mods_true 'DISALLOW_FILE_MODS=true' -e WORDPRESS_DISALLOW_FILE_MODS=true
    _expect disallow_file_mods_invalid_keeps_default $'DISALLOW_FILE_MODS=false\nWORDPRESS_DISALLOW_FILE_MODS=sometimes is neither true nor false, using false' -e WORDPRESS_DISALLOW_FILE_MODS=sometimes

    _expect memory_limit_default 'WP_MEMORY_LIMIT=undefined'
    _expect memory_limit_set "WP_MEMORY_LIMIT='256M'" -e WORDPRESS_MEMORY_LIMIT=256M
    _expect memory_limit_invalid_ignored $'WP_MEMORY_LIMIT=undefined\nWORDPRESS_MEMORY_LIMIT=lots is no size such as 256M, WordPress keeps its own limit' -e WORDPRESS_MEMORY_LIMIT=lots

    _expect nginx_host_default $'rest_url=https://blog.example.org/wp-json/\nself_call=http://wordpress-nginx:8080/wp-cron.php' -e WORDPRESS_HOME=https://blog.example.org
    _expect nginx_host_set $'rest_url=https://blog.example.org/wp-json/\nself_call=http://web:8081/wp-cron.php' -e WORDPRESS_HOME=https://blog.example.org -e NGINX_HOST=web:8081

    # php-fpm -i reports the values the FastCGI SAPI uses; the CLI forces its own time limits
    _limits() {
        docker run --rm --pull=never "$@" "${IMAGE}" -i 2>&1 \
            | sed -n -E 's/^(memory_limit|upload_max_filesize|post_max_size|max_file_uploads|max_execution_time|max_input_time) => ([^ ]+) => .*/\1=\2/p'
    }
    EXPECTED=$'max_execution_time=30\nmax_file_uploads=1000\nmax_input_time=60\nmemory_limit=512M\npost_max_size=100G\nupload_max_filesize=10G'
    DEFAULTS=$(_limits)
    if [[ "${DEFAULTS}" == "${EXPECTED}" ]]; then
        _pass "php_limits_inherited_default"
    else
        _fail "php_limits_inherited_default" "$(echo ${DEFAULTS})"
    fi
    EXPECTED=$'max_execution_time=11\nmax_file_uploads=7\nmax_input_time=12\nmemory_limit=256M\npost_max_size=3G\nupload_max_filesize=2G'
    SET=$(_limits -e MEMORY_LIMIT=256M -e UPLOAD_MAX_FILESIZE=2G -e POST_MAX_SIZE=3G \
        -e MAX_FILE_UPLOADS=7 -e MAX_EXECUTION_TIME=11 -e MAX_INPUT_TIME=12)
    if [[ "${SET}" == "${EXPECTED}" ]]; then
        _pass "php_limits_inherited_from_environment"
    else
        _fail "php_limits_inherited_from_environment" "$(echo ${SET})"
    fi
    # grep reads the whole output: grep -q stops at the first match, php-fpm then dies on SIGPIPE and pipefail fails the check
    SET_CONFIG=$(docker run --rm --pull=never -e MAX_CHILDREN=9 "${IMAGE}" -tt 2>&1)
    if grep -q 'pm.max_children = 9$' <<<"${SET_CONFIG}"; then
        _pass "max_children_inherited_from_environment"
    else
        _fail "max_children_inherited_from_environment" "MAX_CHILDREN=9 does not reach pm.max_children"
    fi

    # CVE-2026-109618 and CVE-2026-109619, inherited from mwaeckerlin/php-fpm
    INFO=$(docker run --rm --pull=never "${IMAGE}" -i 2>&1)
    if grep -Eiq 'session\.upload_progress\.enabled( => |</td><td class="v">)(Off|0)' <<< "${INFO}"; then
        _pass "session_upload_progress_off"
    else
        _fail "session_upload_progress_off" "$(grep -i 'session.upload_progress.enabled' <<< "${INFO}" || echo 'setting not reported')"
    fi
    CONFIG=$(docker run --rm --pull=never "${IMAGE}" -tt 2>&1)
    if grep -Eq 'session\.upload_progress\.enabled\] = (off|no|0)' <<< "${CONFIG}"; then
        _pass "session_upload_progress_locked"
    else
        _fail "session_upload_progress_locked" "the pool does not lock session.upload_progress.enabled off"
    fi
    if grep -Eq 'fatal_error_backtraces\] = (off|no|0)' <<< "${CONFIG}"; then
        _pass "fatal_error_backtraces_locked"
    else
        _fail "fatal_error_backtraces_locked" "the pool does not lock fatal_error_backtraces off"
    fi
fi

echo ""
echo "==> Config contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
