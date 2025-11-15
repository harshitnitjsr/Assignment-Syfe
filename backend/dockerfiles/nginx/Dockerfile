# OpenResty Nginx with Lua Support
# Built with specific configure options for production use

FROM ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3 \
    libpcre3-dev \
    zlib1g \
    zlib1g-dev \
    libssl-dev \
    libgeoip-dev \
    libgd-dev \
    wget \
    git \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and extract OpenResty
WORKDIR /tmp
ARG OPENRESTY_VERSION=1.21.4.1
RUN wget https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz \
    && tar -xzf openresty-${OPENRESTY_VERSION}.tar.gz \
    && cd openresty-${OPENRESTY_VERSION}

# Build OpenResty with specified configure options
WORKDIR /tmp/openresty-${OPENRESTY_VERSION}
RUN ./configure --prefix=/opt/openresty \
    --with-pcre-jit \
    --with-ipv6 \
    --without-http_redis2_module \
    --with-http_iconv_module \
    --with-http_postgres_module \
    -j8 \
    && make -j8 \
    && make install

# Final runtime image
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpcre3 \
    libssl3 \
    libgeoip1 \
    libgd3 \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenResty from builder
COPY --from=builder /opt/openresty /opt/openresty

# Add OpenResty to PATH
ENV PATH="/opt/openresty/bin:/opt/openresty/nginx/sbin:${PATH}"

# Create nginx user
RUN useradd -r -s /bin/false nginx

# Create necessary directories
RUN mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/conf.d \
    && chown -R nginx:nginx /var/log/nginx /var/cache/nginx \
    && mkdir -p /opt/openresty/nginx/logs \
    /opt/openresty/nginx/client_body_temp \
    /opt/openresty/nginx/proxy_temp \
    /opt/openresty/nginx/fastcgi_temp \
    /opt/openresty/nginx/uwsgi_temp \
    /opt/openresty/nginx/scgi_temp \
    && chown -R nginx:nginx /opt/openresty

# Copy nginx configuration
COPY nginx.conf /opt/openresty/nginx/conf/nginx.conf
COPY wordpress-proxy.conf /etc/nginx/conf.d/wordpress-proxy.conf
COPY lua/ /opt/openresty/nginx/lua/

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Switch to nginx user
USER nginx

# Start nginx
CMD ["/opt/openresty/bin/openresty", "-g", "daemon off;"]
