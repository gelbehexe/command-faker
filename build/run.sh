#!/bin/bash

DEBUG="${DEBUG:-0}"
cur_path="$(dirname "$0")"
composer_directory="$cur_path/docker/"
cd "$cur_path/.." || exit 1
cur_script="./build/$(basename "$0")"
aliasNames=("composer" "php" "phpcs" "phpcbf" "phpunit" "test")

trap cleanUp EXIT
tmpFiles=()

is_service() {
  local res
  local service="$1"
  res=$(docker compose --project-directory "$composer_directory" config --format json | jq -r ".services.${service}" 2> /dev/null)
  if [ "$res" = "null" ]; then
    return 1
  fi
  return 0
}

is_valid_command() {
  is_php_command && return 0;
  case $1 in
    build|rebuild|composer|phpcs|phpcbf|archive)
      return 0;
      ;;
  esac
  is_service && return 0;
  return 1;
}

is_php_command() {
#  is_service "$1" && return 0
  case $1 in
  php|phpunit|test|pint)
    return 0;
    ;;
  esac
  return 1
}

has_help_arg() {
  local args=("$@")
  for arg in "${args[@]}"; do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ] || [ "$arg" == "help" ]; then
      return 0;
    fi
    is_valid_command "$arg" && return 1
  done
  return 1
}

checkCommand() {
  command -v "$1" > /dev/null || exitWithErr "Missing dependency '$1'"
}

getServices() {
  #docker compose --file ./docker/docker-compose.yml config --format json | jq -crM --args ".services | keys"
  docker compose --project-directory="build/docker" config --format json | jq -crM --args ".services | keys"
}

showHelp() {
  err "$(basename "$0")"
  err "=============="
  err "Run commands in docker container"
  err ""
  err "Usage:"
  err "------"
  err -e "\t$0 build|rebuild|<service> [arg...]"
  err -e "\t\t  build: Build docker images"
  err -e "\t\trebuild: Build docker images without cache"
  err -e "\t\tcomposer: Run composer"
  err -e "\t\tarchive: Build a dist archive in zip format (based on composer archive command)"
  err -e "\t\tpint: test or fix php errors"
  err -e "\t\t<service>: One of the following: $(getServices)"
  err -e "\t\talias: set up aliases in current shell (composer and services)"
  err -e "\t\tunalias: remove aliases in current shell (composer and services)"
  err ""
}

createTmpFile() {
  local template
  local autoRemove=1
  local tmpDir="${TMPDIR:-/tmp}"
  local tempVar="tmpFile"
  local arg
  local args=()

  if [ $# -gt 3 ]; then
    err "'createTmpFile': Too many arguments"
    return 1
  fi

  for arg in "$@"; do
    if [[ $arg == *XXX* ]]; then
      # interpret as template name
      template="$arg"
    elif [ "$arg" = "0" ] || [ "$arg" = "1" ]; then
      # interpret as autoRemove switch
      autoRemove=$arg
    elif [[ "$arg" =~ ^[a-z][a-zA-Z0-9_]*$ ]]; then
      # interpret as template file name variable
      tempVar="$arg"
    fi
  done

  if [ -n "$template" ]; then
    t="$(dirname "$template")"
    if [ -n "$t" ] && [[ $t != . ]]; then
      tmpDir="$t"
    fi
    template="$(basename "$template")"
  fi

  if [ "$DEBUG" -ne 0 ]; then
    template="${template:-tmp.XXXXXXXXXX}"
    tmpFile="$tmpDir/$(echo "$template" | sed -E 's/XXX+/tmp-DEBUG/g')"
    local errMsg=""
    if [ -z "$tmpFile" ]; then
      errMsg="(DEBUG) Could not get temporary file name for '$template'"
    elif ! touch "$tmpFile"; then
      errMsg="(DEBUG) Could not create temporary file '$template'"
    fi
    test -n "$errMsg" && exitWithErr "$errMsg"
  else
    echo -n ""
    [ -n "$tmpDir" ] && args+=("-p" "$tmpDir")
    [ -n "$template" ] && args+=("$template")
    # shellcheck disable=SC2068
    tmpFile="$(mktemp -u ${args[@]})" || exitWithErr "Could not create temporary file '$template'"
  fi

  if [ "$autoRemove" -eq 1 ]; then
    tmpFiles+=("$tmpFile")
  fi
  # shellcheck disable=SC2229
  read -r "$tempVar" < <(echo "$tmpFile")

}

enableComposerCompletion() {
  err ""
  err -n "Updating composer autocomplete ... "
  # shellcheck disable=SC2086,SC2016
  docker compose --project-name "$(basename "$PWD")" \
   --project-directory "$composer_directory" \
   run ${env_args[*]} --rm php composer completion bash \
    | sed 's/if \[\[ $sf_cmd_type != "function"/\0 \&\& $sf_cmd_type != "alias"/g' \
    | sed "s/sf_cmd=\$(alias \$sf_cmd.*$/echo -n ''/g" \
    | sed 's/completecmd=("$sf_cmd"/completecmd=(".\/build\/run.sh" "composer"/g'
}

err() {
  >&2 echo "$@"
}

exitWithErr() {
  # shellcheck disable=SC2145
  err "ERROR: $@"
  exit 1
}

removeTempFiles() {
  if [ "${#tmpFiles[@]}" -eq 0 ]; then
    return;
  fi
  err ""
  err "Removing temporary files:"

  for tmpFile in "${tmpFiles[@]}"; do
    err -n "- '$tmpFile' ... "
    if [[ $tmpFile == *tmp-DEBUG* ]]; then
      err "KEEP"
    else
      rm "$tmpFile" && err "OK"
    fi
  done
}
cleanUp() {
  removeTempFiles
}



setupAliases() {
  local tmpFile
  createTmpFile "/tmp/TXXX.sh" "tmpFile" 0

  err "Setting up aliases:"
  for aliasName in "${aliasNames[@]}"; do
    err -n "- $aliasName ... "
    echo "alias $aliasName='$cur_script $aliasName'" || exit 1
    err "OK"
  done > "$tmpFile"

  # TODO: enableComposerCompletion not working yet
  enableComposerCompletion >> "$tmpFile" && err "OK"

  if [[ $tmpFile == *tmp-DEBUG* ]]; then
    echo "echo 'Keep debug tmpFile '$tmpFile''" >> "$tmpFile"
  else
    echo "rm $tmpFile" >> "$tmpFile"
  fi

  echo "Type 'source $tmpFile' and press enter to enable aliases"
}

shutdownAliases() {
  local tmpFile
  createTmpFile "/tmp/TXXX.sh" "tmpFile" 0


  err "Removing aliases:"
  for aliasName in "${aliasNames[@]}"; do
    err -n "- $aliasName ... "
    echo "unalias $aliasName" || exit 1
    err "OK"
  done > "$tmpFile"

  if [[ $tmpFile == *tmp-DEBUG* ]]; then
    echo "echo 'Keep debug tmpFile '$tmpFile''" >> "$tmpFile"
  else
    echo "rm $tmpFile" >> "$tmpFile"
  fi

  echo "Type 'source $tmpFile' and press enter to remove aliases"
}

is_debug=0
env_args=("-e GOSU_UID=${GOSU_UID:-$(id -u)}" "-e GOSU_GID=${GOSU_GID:-$(id -g)}")
if has_help_arg "$@"; then
    checkCommand jq
    showHelp
    exit;
#if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  set -- "help"
fi
if [ "$1" == "debug" ]; then
  shift
  is_php_command "$1" || exitWithErr "'$1' is not a debuggable command"
  is_debug=1
elif [ "$1" == "alias" ]; then
    setupAliases
    exit
elif [ "$1" == "unalias" ]; then
    shutdownAliases
    exit 0
fi


if  [ $# -eq 0 ] || [[ $1 == -* ]]; then
  set -- "php" "${@}"
elif [[ $1 == *\.php ]]; then
  set -- "php" "-f" "${@}"
fi
if [ $is_debug -eq 1 ]; then

  env_args+=("-e XDEBUG_MODE=develop,debug,coverage" -e "XDEBUG_CONFIG=client_host=host.docker.internal" -e "PHP_IDE_CONFIG=${PHP_IDE_CONFIG:-serverName=docker-server}" "-e XDEBUG_SESSION=1")

  args=("php" "-dzend_extension=xdebug")

  if [ "$1" == "php" ]; then
    shift
    # shellcheck disable=SC2206
    args+=($*)
  else
    # test/phpunit
    shift
    args+=("-f" "vendor/bin/phpunit")

    if [ "$#" -gt 0 ]; then
      args+=("--" "${@}")
    fi
  fi
  set -- "${args[@]}"
  service="php"
elif is_php_command "$1"; then
  # php command without debug
  args=("php")
  if [ "$1" == "php" ]; then
    shift
    args+=("${@}")
  else
    # test/phpunit - pint
    if [ "$1" == "pint" ]; then
      vendor_bin="vendor/bin/pint"
    else
      vendor_bin="vendor/bin/phpunit"
    fi

    shift
    args+=("-f" "${vendor_bin}")

    if [ "$#" -gt 0 ]; then
      args+=("--" "${@}")
    fi
  fi
  set -- "${args[*]}"
  service="php"
else
  service="$1"
fi

case $service in
  build)
    docker compose --progress=plain --project-name "$(basename "$PWD")" --project-directory "$composer_directory" build 2>&1 | tee "$PWD/.build.log"
    ;;
  rebuild)
    docker compose --progress=plain --project-name "$(basename "$PWD")" --project-directory "$composer_directory" build --no-cache 2>&1 | tee "$PWD/.build.log"
    ;;
  composer)
    # shellcheck disable=SC2086,SC2048
    docker compose --project-name "$(basename "$PWD")" --project-directory "$composer_directory" run ${env_args[*]} --rm php $*
    ;;
  phpcs|phpcbf)
    is_service "$service" || exitWithErr "Service '$service' does not exist"
    shift
    # shellcheck disable=SC2086,SC2048
    docker compose --project-name "$(basename "$PWD")" --project-directory "$composer_directory" run ${env_args[*]} --rm "$service" -v $*
    ;;
  archive)
    shift
    # shellcheck disable=SC2086,SC2048
    GOSU_UID="$GOSU_UID" GOSU_GID="$GOSU_GID" docker compose --project-name "$(basename "$PWD")" --project-directory "$composer_directory" run --rm php composer archive --dir=archive --format zip $*
    ;;
  *)
    [ "$is_debug" -eq 1 ] || is_service "$service" || exitWithErr "Service '$service' does not exist"
    # shellcheck disable=SC2086,SC2048
    docker compose --project-name "$(basename "$PWD")" --project-directory "$composer_directory" run ${env_args[*]} --rm $*
    ;;
esac
