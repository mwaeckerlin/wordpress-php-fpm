# Minimalistic Secure PHP-FPM Docker Image for WordPress

This image is about 116MB in size and has no shell, so it is small, fast and secure.

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
    - `WORDPRESS_HOME`: Base URL of the wordpress home.
    - `WORDPRESS_SITEURL`: Base URL of the wordpress site.
    - `WORDPRESS_TABLE_PREFIX`: table prefix; default `wp_`, 


## Persistence and Volumes

- WordPress lives in `/app`; all mutable data (uploads, plugins, themes) is under `/app/wp-content`. Mount one shared volume on `/app/wp-content` in both [mwaeckerlin/wordpress-php-fpm] and [mwaeckerlin/wordpress-nginx] so they see the same files.
- The generated secrets are stored under `/app/wp-secrets`. Mount that volume only into [mwaeckerlin/wordpress-php-fpm] so keys persist and nginx cannot read them.


[mwaeckerlin/php-fpm]: https://github.com/mwaeckerlin/php-fpm "PHP-FPM base image"
[mwaeckerlin/wordpress-php-fpm]: https://github.com/mwaeckerlin/wordpress-php-fpm "WordPress PHP-FPM backend"
[mwaeckerlin/wordpress-nginx]: https://github.com/mwaeckerlin/wordpress-nginx "WordPress NGINX frontend"
[mwaeckerlin/wordpress]: https://github.com/mwaeckerlin/wordpress "WordPress monorepo"
