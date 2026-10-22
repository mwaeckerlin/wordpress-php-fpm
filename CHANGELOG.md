# Changelog

- 2026-10-22 **1.0.2**
    - REST URLs handed to the browser carry the external address also when `NGINX_HOST` names another internal host; before, they kept the internal host unless it was `wordpress-nginx:8080`
    - `WORDPRESS_DEBUG` accepts `all` again, which writes the WordPress debug log, and `display`, which sends errors to the container log; both had silently switched debugging off
    - An unknown `WORDPRESS_DEBUG` value is named in the container log
    - `WORDPRESS_DISALLOW_FILE_MODS` (default `false`) forbids installing and updating plugins, themes and language packs from the administration
    - `WORDPRESS_MEMORY_LIMIT` sets the memory WordPress asks for; unset, WordPress keeps its own limit

- 2026-09-26 **1.0.1**
    - An installation without its own keys and salts gets random ones on the first start, as documented; the image had set all eight to the same fixed value, so login cookies of every such installation could be forged with it
    - The database password has no default any more: without `WORDPRESS_DB_PASSWORD` the connection fails at once instead of coming up on the publicly known password `wordpress`
    - The image is published for amd64 and arm64 under one tag, built, tested and published automatically on every change and every week
