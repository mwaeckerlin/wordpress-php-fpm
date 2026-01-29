FROM mwaeckerlin/very-base AS wordpress
WORKDIR /app
ADD https://wordpress.org/latest.tar.gz /tmp/wordpress.tar.gz
RUN tar xzf /tmp/wordpress.tar.gz --strip-components=1
RUN mkdir wp-secrets
RUN ${ALLOW_USER} wp-content wp-secrets
COPY wp-config.php wp-config.php

FROM mwaeckerlin/php-fpm
ENV WORDPRESS_DB_HOST "mysql"
ENV WORDPRESS_DB_PORT "3306"
ENV WORDPRESS_DB_NAME "wordpress"
ENV WORDPRESS_DB_USER "wordpress"
ENV WORDPRESS_DB_PASSWORD "wordpress"
ENV WORDPRESS_DB_CHARSET "utf8mb4"
ENV WORDPRESS_DB_COLLATE ""
ENV WORDPRESS_TABLE_PREFIX "wp_"
ENV WORDPRESS_AUTH_KEY "change-me"
ENV WORDPRESS_SECURE_AUTH_KEY "change-me"
ENV WORDPRESS_LOGGED_IN_KEY "change-me"
ENV WORDPRESS_NONCE_KEY "change-me"
ENV WORDPRESS_AUTH_SALT "change-me"
ENV WORDPRESS_SECURE_AUTH_SALT "change-me"
ENV WORDPRESS_LOGGED_IN_SALT "change-me"
ENV WORDPRESS_NONCE_SALT "change-me"
ENV WORDPRESS_HOME ""
ENV WORDPRESS_SITEURL ""
ENV WORDPRESS_DEBUG "false"
ENV NGINX_HOST "wordpress-nginx:8080"
COPY --from=wordpress /app /app
