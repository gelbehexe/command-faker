#!/bin/bash

cur_path="$(dirname "$0")"
composer_file="$cur_path/docker/docker-compose.yml"
composer_directory="$cur_path/docker/"
cd "$cur_path/.."
GOSU_UID="${GOSU_UID:-$(id -u)}"
GOSU_GID="${GOSUgGID:-$(id -g)}"
#echo $composer_file
#exit

if [ "$#" -eq 0 ]; then
  set -- shell
fi
service="$1"

is_service() {
  local service="$1"
  local res=$(docker compose --project-directory "$composer_directory" config --format json | jq -r ".services.${service}" 2> /dev/null)
  if [ "$res" = "null" ]; then
    return 1
  fi
  return 0
}

checkCommand() {
  command -v "$1" > /dev/null || exitWithErr "Missing dependency '$1'"
}

getServices() {
  #docker compose --file ./docker/docker-compose.yml config --format json | jq -crM --args ".services | keys"
  docker compose --project-directory="build/docker" config --format json | jq -crM --args ".services | keys"
}

showHelp() {
  err "$(basename $0)"
  err "=============="
  err "Run commands in docker container"
  err ""
  err "Usage:"
  err "------"
  err -e "\t$0 build|rebuild|<service> [arg...]"
  err -e "\t\t  build: Build docker images from composer_file"
  err -e "\t\trebuild: Build docker images from composer_file without cache"
  err -e "\t\t<service>: One of the following: $(getServices)"
  err ""
}

err() {
  >&2 echo "$@"
}

exitWithErr() {
  err "ERROR: $@"
  exit 1
}

case $service in
  build)
    docker compose --progress=plain --project-name "$(basename $PWD)" --project-directory "$composer_directory" build 2>&1 | tee docker/tmp/build.log
    ;;
  rebuild)
    docker compose --progress=plain --project-name "$(basename $PWD)" --file --project-directory "$composer_directory" build --no-cache 2>&1 | tee docker/tmp/build.log
    ;;
  help)
    checkCommand jq
    showHelp
    ;;
  composer)
    GOSU_UID="$GOSU_UID" GOSU_GID="$GOSU_GID" docker compose --project-name "$(basename $PWD)" --project-directory "$composer_directory" run --rm php "$@"
    ;;
  phpcs|phpcbf)
    is_service $service || exitWithErr "Service '$service' does not exist"
    #--report-file=./build/docker/tmp/phpcs.report.log
    shift
    GOSU_UID="$GOSU_UID" GOSU_GID="$GOSU_GID" docker compose --project-name "$(basename $PWD)" --project-directory "$composer_directory" run --rm "$service" -nv "$@"
    ;;
  archive)
    shift
    GOSU_UID="$GOSU_UID" GOSU_GID="$GOSU_GID" docker compose --project-name "$(basename $PWD)" --project-directory "$composer_directory" run --rm php composer archive --dir=archive --format zip "$@"
    ;;
  *)
    is_service $service || exitWithErr "Service '$service' does not exist"
    GOSU_UID="$GOSU_UID" GOSU_GID="$GOSU_GID" docker compose --project-name "$(basename $PWD)" --project-directory "$composer_directory" run --rm "$@"
    ;;
esac
