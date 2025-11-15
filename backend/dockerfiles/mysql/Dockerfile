# Production-grade MySQL for WordPress
# NOTE: The default mysql:8.0 tag can resolve to an RPM-based (el9) image variant
# which does not include apt-get. We explicitly use the Debian variant so that
# apt-get commands succeed during image build. This fixes prior build failures
# ("apt-get: command not found") that caused ImagePullBackOff for the MySQL pod.
FROM mysql:8.0-debian

# Install additional tools (curl is lightweight; remove/adjust if unnecessary)
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Custom MySQL configuration
COPY my.cnf /etc/mysql/conf.d/wordpress.cnf

# Initialization scripts
COPY init-wordpress.sql /docker-entrypoint-initdb.d/

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} || exit 1

# Create directory for backups
RUN mkdir -p /var/backups/mysql \
    && chown -R mysql:mysql /var/backups/mysql

# Expose MySQL port
EXPOSE 3306

# Use default MySQL entrypoint
