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

echo ""
echo "==> Config contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
