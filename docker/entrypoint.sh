#!/bin/sh
set -eu

CONF_DIR=/usr/local/tomcat/webapps/ROOT/WEB-INF/config/repo-conf
CONF_TEMPLATE=/opt/magnolia/config/jackrabbit-bundle-postgres-search.xml
CONF="$CONF_DIR/jackrabbit-bundle-postgres-search.xml"
MAGNOLIA_SUPERUSER_PASSWORD_FILE=/tmp/magnolia-superuser-password
MAGNOLIA_DATA_DIR=/usr/local/tomcat/webapps/ROOT/repositories

xml_escape() {
  printf '%s' "$1" |
    sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' \
      -e "s/'/\&apos;/g"
}

if [ -z "${DB_URL:-}" ] || [ -z "${DB_USER:-}" ] || [ -z "${DB_PASSWORD:-}" ]; then
  printf 'DB_URL, DB_USER, and DB_PASSWORD must all be set.\n' >&2
  exit 1
fi

if [ -z "${MAGNOLIA_SUPERUSER_PASSWORD:-}" ]; then
  printf 'MAGNOLIA_SUPERUSER_PASSWORD must be set.\n' >&2
  exit 1
fi

umask 077
printf '%s' "$MAGNOLIA_SUPERUSER_PASSWORD" > "$MAGNOLIA_SUPERUSER_PASSWORD_FILE"
unset MAGNOLIA_SUPERUSER_PASSWORD

export DB_URL_XML
export DB_USER_XML
export DB_PASSWORD_XML
DB_URL_XML=$(xml_escape "$DB_URL")
DB_USER_XML=$(xml_escape "$DB_USER")
DB_PASSWORD_XML=$(xml_escape "$DB_PASSWORD")

mkdir -p "$CONF_DIR" "$MAGNOLIA_DATA_DIR/config"
envsubst '${DB_URL_XML} ${DB_USER_XML} ${DB_PASSWORD_XML}' < "$CONF_TEMPLATE" > "$CONF"

JAVA_OPTS="${JAVA_OPTS:-} -Dmagnolia.superuser.bootstrap.password_file=$MAGNOLIA_SUPERUSER_PASSWORD_FILE -Dmagnolia.superuser.bootstrap.interactive_setup=false"
export JAVA_OPTS

exec "$@"
