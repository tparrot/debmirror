#!/bin/bash
set -uo pipefail


[[ "$(whoami)" == "www-data" ]] || exit 1

# cd /var/local/repository/gpg/mirror
# Renew nginx keys
curl https://nginx.org/keys/nginx_signing.key | gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --import

# Renew maintainers GPG keys
# cd /var/local/repository/gpg/debian-keyring
# rsync -az --delete --progress keyring.debian.org::keyrings/keyrings/ .
# gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --import *.gpg

# Remove expired keys
gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --list-keys --with-colons \
  | awk -F: '$1 == "pub" && ($2 == "e" || $2 == "r") { print $5 }' \
  | xargs gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --batch --yes --delete-keys

# Mirror repositories
cd /var/local/repository/public

# Import repo signing key
gpg --import --keyring /var/www/.gnupg/trustedkeys.kbx --batch ../gpg/5F8B0B29BC2F975EBFE441C848DFAD4D42B1FF84.key

( debmirror --config-file=../conf/debmirror-debian.conf ./debian;debmirror --config-file=../conf/debmirror-debian-archive.conf ./debian-archive --rsync-extra=none; debmirror --config-file=../conf/debmirror-debian-security-archive.conf ./debian-security-archive --rsync-extra=none; debmirror --config-file=../conf/debmirror-debian-security.conf ./debian-security; debmirror --config-file=../conf/debmirror-nginx.conf ./nginx --rsync-extra=none; debmirror --config-file=../conf/debmirror-varnish.conf varnishcache/varnish60lts --rsync-extra=none; debmirror --config-file=../conf/debmirror-hitch.conf hitch --rsync-extra=none; debmirror --config-file=../conf/debmirror-rabbitmq.conf rabbitmq/rabbitmq-server --rsync-extra=none; debmirror --config-file=../conf/debmirror-docker.conf docker --rsync-extra=none)

# Mirror insert custom GPG keys for expired repositories
for expired_repo in sury-php/20220702/dists/stretch nginx/dists/stretch; do ( cd "${expired_repo}"; gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx -abs -u 5F8B0B29BC2F975EBFE441C848DFAD4D42B1FF84 --passphrase-file /var/local/repository/gpg/5F8B0B29BC2F975EBFE441C848DFAD4D42B1FF84.pw --batch --yes --pinentry-mode loopback -o Release.gpg Release; rm InRelease ); done

# Render information about GPG keys into repos webserver
( gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --refresh-keys && gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --armor --export > ./keys/100-mirrors.gpg.asc; for key in $(gpg --list-keys --keyid-format=none --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx | tee ./keys/100-mirrors.txt | sed -e '/pub\|uid\|sub\|^$\|-\|\d/d'); do gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --export --armor ${key} > ./keys/200-mirror-${key}.gpg.asc; gpg --no-default-keyring --keyring /var/www/.gnupg/trustedkeys.kbx --export ${key} > ./keys/200-mirror-${key}.gpg; done )
