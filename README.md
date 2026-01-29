# Minimalistic Secure PHP-FPM Docker Image for WordPress

This image is about 166MB in size and has no shell, so it is small, fast and secure.

Implements a PHP-FPM WordPress backend based on [mwaeckerlin/php-fpm].

Only used as one part in [mwaeckerlin/wordpress], see there for more information.

This is the most lean and secure image for a PHP WordPress server:
 - extremely small size, minimalistic dependencies
 - no shell, only the server command
 - small attack surface
 - starts as non root user


## Configuration

  - mandatory to change
    - `WORDPRESS_DB_PASSWORD`: DB user password; **change in production** to a strong secret matching your DB.
  - optional to change
    - `WORDPRESS_DB_USER`: DB user; defaults to `wordpress`, change if you use another user.
    - `WORDPRESS_DB_NAME`: DB name; defaults to `wordpress`, change if your schema differs.
    - `WORDPRESS_DB_HOST`: DB host; defaults to `mysql`, set to your DB host it it's named differently.
    - `WORDPRESS_DB_PORT`: DB port; defaults to `3306`, fits mysql and mariadb, adjust if your DB listens elsewhere.
    - `WORDPRESS_HOME`: Base URL of the wordpress home (optional).
    - `WORDPRESS_SITEURL`: Base URL of the wordpress site (optional).
    - `WORDPRESS_TABLE_PREFIX`: table prefix; default `wp_`, 
    - `NGINX_HOST`: Internal hostname and port for container-to-container communication (default: `wordpress-nginx:8080`). Used to reroute WordPress's own requests (REST API, WP-Cron, etc.) through the Docker container network instead of external ports. Optional; if unset, the default is used.


## Persistence and Volumes

- WordPress lives in `/app`; all mutable data (uploads, plugins, themes) is under `/app/wp-content`. Mount one shared volume on `/app/wp-content` in both [mwaeckerlin/wordpress-php-fpm] and [mwaeckerlin/wordpress-nginx] so they see the same files.
- The generated secrets are stored under `/app/wp-secrets`. Mount that volume only into [mwaeckerlin/wordpress-php-fpm] so keys persist and nginx cannot read them.


## Internal Container Routing (REST API & WP-Cron)

WordPress makes internal requests to itself for REST API calls, WP-Cron jobs, and other operations. This image includes a filter in `wp-config.php` that automatically reroutes these self-referencing requests through the Docker container network instead of external ports.

**How it works:**
1. External requests can reach WordPress via `WORDPRESS_HOME` / `WORDPRESS_SITEURL` if set (e.g., `http://localhost:8321`).
2. Any self-call to `localhost` or `127.0.0.1` is always rerouted to the internal host (default `wordpress-nginx:8080`).
3. If `WORDPRESS_HOME` / `WORDPRESS_SITEURL` are set, self-calls to these URLs are rerouted to the same internal host.
4. This avoids port binding issues and keeps internal traffic on the Docker network.

**Environment Variables:**
- `WORDPRESS_HOME`: External URL where WordPress is accessible from outside the container (optional)
- `WORDPRESS_SITEURL`: External URL for the WordPress site (optional)
- `NGINX_HOST`: Internal hostname:port for container-to-container requests (optional, default: `wordpress-nginx:8080`). Note: include the port number if you override it.

**Example Docker Compose setup (with explicit URLs):**
```yaml
wordpress-php-fpm:
  environment:
    WORDPRESS_HOME: http://localhost:8123
    WORDPRESS_SITEURL: http://localhost:8123
    NGINX_HOST: wordpress-nginx:8080  # optional override

wordpress-nginx:
  hostname: wordpress-nginx
  ports:
    - "8123:8080"  # External:Internal
```

If you omit `WORDPRESS_HOME` / `WORDPRESS_SITEURL`, localhost/127.0.0.1 self-calls are still rerouted automatically to `wordpress-nginx:8080` by default.


[mwaeckerlin/php-fpm]: https://github.com/mwaeckerlin/php-fpm "PHP-FPM base image"
[mwaeckerlin/wordpress-php-fpm]: https://github.com/mwaeckerlin/wordpress-php-fpm "WordPress PHP-FPM backend"
[mwaeckerlin/wordpress-nginx]: https://github.com/mwaeckerlin/wordpress-nginx "WordPress NGINX frontend"
[mwaeckerlin/wordpress]: https://github.com/mwaeckerlin/wordpress "WordPress monorepo"
