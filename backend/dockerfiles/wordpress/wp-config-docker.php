<?php

/**
 * WordPress Configuration for Docker/Kubernetes
 * Uses environment variables for configuration
 */

// ** MySQL settings ** //
define('DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress');
define('DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress');
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'wordpress');
define('DB_HOST', getenv('WORDPRESS_DB_HOST') ?: 'mysql:3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// ** Authentication Keys and Salts ** //
define('AUTH_KEY',         getenv('WORDPRESS_AUTH_KEY') ?: 'put your unique phrase here');
define('SECURE_AUTH_KEY',  getenv('WORDPRESS_SECURE_AUTH_KEY') ?: 'put your unique phrase here');
define('LOGGED_IN_KEY',    getenv('WORDPRESS_LOGGED_IN_KEY') ?: 'put your unique phrase here');
define('NONCE_KEY',        getenv('WORDPRESS_NONCE_KEY') ?: 'put your unique phrase here');
define('AUTH_SALT',        getenv('WORDPRESS_AUTH_SALT') ?: 'put your unique phrase here');
define('SECURE_AUTH_SALT', getenv('WORDPRESS_SECURE_AUTH_SALT') ?: 'put your unique phrase here');
define('LOGGED_IN_SALT',   getenv('WORDPRESS_LOGGED_IN_SALT') ?: 'put your unique phrase here');
define('NONCE_SALT',       getenv('WORDPRESS_NONCE_SALT') ?: 'put your unique phrase here');

// ** WordPress Database Table prefix ** //
$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

// ** WordPress debugging mode ** //
define('WP_DEBUG', getenv('WORDPRESS_DEBUG') === 'true');
define('WP_DEBUG_LOG', getenv('WORDPRESS_DEBUG_LOG') === 'true');
define('WP_DEBUG_DISPLAY', false);

// ** Redis Cache Configuration ** //
define('WP_REDIS_HOST', getenv('REDIS_HOST') ?: 'redis');
define('WP_REDIS_PORT', getenv('REDIS_PORT') ?: 6379);
define('WP_CACHE', true);

// ** Performance ** //
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');
define('CONCATENATE_SCRIPTS', false);
define('COMPRESS_SCRIPTS', true);
define('COMPRESS_CSS', true);
define('ENFORCE_GZIP', true);

// ** Security ** //
define('DISALLOW_FILE_EDIT', true);
define('FORCE_SSL_ADMIN', getenv('WORDPRESS_FORCE_SSL') === 'true');

// ** Auto-update ** //
define('WP_AUTO_UPDATE_CORE', 'minor');

// ** Absolute path to the WordPress directory ** //
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
