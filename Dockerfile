FROM mwaeckerlin/very-base as wordpress
ADD https://wordpress.org/latest.tar.gz /tmp/wordpress.tar.gz
RUN mkdir -p /root && tar xzf /tmp/wordpress.tar.gz -C /root && mv /root/wordpress /root/app

FROM mwaeckerlin/php-fpm

ENV WORDPRESS_DB_HOST "mysql" \
    WORDPRESS_DB_NAME "wordpress" \
    WORDPRESS_DB_USER "wordpress" \
    WORDPRESS_DB_PASSWORD "wordpress"

COPY --from=wordpress /root/app /app
WORKDIR /app
