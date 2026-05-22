#!/bin/sh
set -e

if [ ! -f vendor/autoload.php ]; then
    echo "Installing Composer dependencies..."
    composer install --no-interaction --prefer-dist
fi

echo "Waiting for database..."

until php -r '
    $url = getenv("DATABASE_URL");
    if (!$url) {
        fwrite(STDERR, "DATABASE_URL is not set\n");
        exit(1);
    }
    $parts = parse_url($url);
    $dsn = sprintf(
        "mysql:host=%s;port=%d;dbname=%s",
        $parts["host"],
        $parts["port"] ?? 3306,
        ltrim($parts["path"] ?? "", "/")
    );
    new PDO($dsn, $parts["user"], urldecode($parts["pass"]));
' >/dev/null 2>&1
do
    sleep 2
done

echo "Database is ready"

echo "Running migrations..."
php bin/console doctrine:migrations:migrate --no-interaction

echo "Compiling assets..."
php bin/console asset-map:compile

echo "Clearing cache..."
php bin/console cache:clear --no-interaction

echo "Warming cache..."
php bin/console cache:warmup --no-interaction

echo "Starting web server on :8000..."
exec php -S 0.0.0.0:8000 -t public
