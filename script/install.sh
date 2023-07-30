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

echo "Provide your domain and email to setup DPT."
echo "You will be able to change this parameters later in:"
echo "   /opt/dpts/docker-compose.yaml\n"

echo "Enter your domain: "
read DOMAIN
echo "Enter your email address: "
read EMAIL

mkdir -p "$TARGET_FOLDER"
cd "$TARGET_FOLDER"

DOCKER_COMPOSE_YAML_URL=https://raw.githubusercontent.com/far4599/docker-portainer-traefik-stack/main/docker-compose.yaml
if type wget >/dev/null 2>&1; then
   echo "wget -O '$TARGET_FOLDER/docker-compose.yaml' '$DOCKER_COMPOSE_YAML_URL' | sh\n"
elif type curl >/dev/null 2>&1; then
   echo "curl -o '$TARGET_FOLDER/docker-compose.yaml' '$DOCKER_COMPOSE_YAML_URL' | sh\n"
fi

mkdir -p "$TARGET_FOLDER$LE_FOLDER"
docker network create traefik >/dev/null 2>&1
docker compose up -d

clear

printf "${GREEN}DPT is installed and running${RESET}\n\n"

# check if user is in docker group
user=$(logname)
if [ -z "$(id "$user"| grep -i 'docker')" ]; then
  printf "If you want to access docker commands without sudo, "
  echo "add your user to docker group.\n"
  echo "sudo usermod -aG docker \"$user\" && newgrp docker\n"
fi