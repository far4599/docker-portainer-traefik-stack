#!/bin/sh
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

if ! type docker >/dev/null 2>&1; then
  printf "${RED}docker is not installed${RESET}\n\n"
  echo "Install docker first:\n"
  if type wget >/dev/null 2>&1; then
     echo "wget -O - https://get.docker.com/ | sh\n"
  elif type curl >/dev/null 2>&1; then
     echo "curl https://get.docker.com/ | sh\n"
  fi
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  printf "${RED}This script must be run under sudo:${RESET}\n\n"
  echo "sudo $0 \n\n"
  exit 1
fi

TARGET_FOLDER=/opt/dpts
LE_FOLDER=/letsencrypt

echo "Provide your domain and email to setup DPTS."
echo "You will be able to change this parameters later in:"
echo "   /opt/dpts/docker-compose.yaml\n"

echo "Enter your domain: "
read DOMAIN
echo "Enter your email address: "
read EMAIL

docker_compose_yaml=$(cat <<EOF
version: "3.7"

services:
  traefik:
    image: traefik:2.10.3
    restart: always
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--providers.docker"
      - "--providers.docker.exposedByDefault=false"
      - "--providers.docker.network=traefik"
      - "--log.level=ERROR"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=${EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - traefik
    labels:
      traefik.http.routers.http-catchall.rule: hostregexp(\`{host:.+}\`)
      traefik.http.routers.http-catchall.entrypoints: web
      traefik.http.routers.http-catchall.middlewares: redirect-to-https
      traefik.http.middlewares.redirect-to-https.redirectscheme.scheme: https

  portainer:
    image: portainer/portainer-ce:2.18.4-alpine
    command: -H unix:///var/run/docker.sock
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
    networks:
      - traefik
    labels:
      traefik.enable: 'true'
      traefik.http.services.portainer.loadbalancer.server.port: '9000'
      traefik.http.routers.portainer.rule: Host(\`$DOMAIN\`)
      traefik.http.routers.portainer.entrypoints: websecure
      traefik.http.routers.portainer.service: portainer
      traefik.http.routers.portainer.tls.certresolver: myresolver

networks:
  traefik:
    external: true
EOF
)

mkdir -p $TARGET_FOLDER$LE_FOLDER
echo "$docker_compose_yaml" > $TARGET_FOLDER/docker-compose.yaml
cd $TARGET_FOLDER
docker network create traefik >/dev/null 2>&1
docker compose up -d

clear

printf "${GREEN}DPTS is installed and running${RESET}\n\n"

# check if user is in docker group
user=$(logname)
if [ -z "$(id "$user"| grep -i 'docker')" ]; then
  printf "If you want to access docker commands without sudo, "
  echo "add your user to docker group.\n"
  echo "sudo usermod -aG docker \"$user\" && newgrp docker\n"
fi