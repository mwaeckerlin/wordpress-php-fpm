FROM mwaeckerlin/very-base AS wordpress
WORKDIR /app
ADD https://wordpress.org/latest.tar.gz /tmp/wordpress.tar.gz
RUN tar xzf /tmp/wordpress.tar.gz --strip-components=1
RUN mkdir wp-secrets
RUN ${ALLOW_USER} wp-content wp-secrets
COPY wp-config.php wp-config.php

FROM mwaeckerlin/php-fpm
ENV WORDPRESS_DB_HOST="mysql"
ENV WORDPRESS_DB_PORT="3306"
ENV WORDPRESS_DB_NAME="wordpress"
ENV WORDPRESS_DB_USER="wordpress"
ENV WORDPRESS_DB_CHARSET="utf8mb4"
ENV WORDPRESS_DB_COLLATE=""
ENV WORDPRESS_TABLE_PREFIX="wp_"
ENV WORDPRESS_HOME=""
ENV WORDPRESS_SITEURL=""
ENV WORDPRESS_DEBUG="false"
ENV NGINX_HOST="wordpress-nginx:8080"
# No secret is set here: a value in the image is the same in every
# installation. WORDPRESS_DB_PASSWORD has no default, so the database
# connection fails at once until the operator sets it; the keys and salts
# (WORDPRESS_AUTH_KEY and the seven others) are generated at random on the first start by
# wp-config.php and kept in /app/wp-secrets, unless the operator sets them.
COPY --from=wordpress /app /app
