# Changelog

- 2026-09-26 **1.0.1**
    - An installation without its own keys and salts gets random ones on the first start, as documented; the image had set all eight to the same fixed value, so login cookies of every such installation could be forged with it
    - The database password has no default any more: without `WORDPRESS_DB_PASSWORD` the connection fails at once instead of coming up on the publicly known password `wordpress`
    - The image is published for amd64 and arm64 under one tag, built, tested and published automatically on every change and every week
