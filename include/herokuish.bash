# Make sure we're running under a modern Ruby env needed by buildpacks
# TODO: Push to setup/install script - see ruby cartridge for example
ruby -v | grep -q 2\.0
if [ $? -eq 1 ]; then
    exec scl enable ruby200 "$0 $@"
fi

# Uncomment to enable trace logging
export TRACE=true

# Env variables used be Herokuish
export APP_PATH=${OPENSHIFT_DEPENDENCIES_DIR}app
export ENV_PATH=${OPENSHIFT_DEPENDENCIES_DIR}env
export BUILD_PATH=${OPENSHIFT_BUILD_DEPENDENCIES_DIR}build
export CACHE_PATH=${OPENSHIFT_BUILD_DEPENDENCIES_DIR}cache
export IMPORT_PATH=${OPENSHIFT_REPO_DIR}
export BUILDPACK_PATH=${OPENSHIFT_BUILD_DEPENDENCIES_DIR}buildpacks

source $OPENSHIFT_HEROKU_DIR/include/fn.bash
source $OPENSHIFT_HEROKU_DIR/include/cmd.bash
source $OPENSHIFT_HEROKU_DIR/include/buildpack.bash
source $OPENSHIFT_HEROKU_DIR/include/procfile.bash
source $OPENSHIFT_HEROKU_DIR/include/slug.bash

function yaml-keys {
    ruby -e "require 'yaml'; puts YAML.load(\$stdin).keys"
}

function yaml-get {
    ruby -e "require 'yaml'; puts YAML.load(\$stdin)['$1']"
}


if [[ "$BASH_VERSINFO" -lt "4" ]]; then
	echo "!! Your system Bash is out of date: $BASH_VERSION"
	echo "!! Please upgrade to Bash 4 or greater."
	exit 2
fi

readonly app_path="${APP_PATH:-/app}"
readonly env_path="${ENV_PATH:-/tmp/env}"
readonly build_path="${BUILD_PATH:-/tmp/build}"
readonly cache_path="${CACHE_PATH:-/tmp/cache}"
readonly import_path="${IMPORT_PATH:-/tmp/app}"
readonly buildpack_path="${BUILDPACK_PATH:-/tmp/buildpacks}"

declare unprivileged_user="$USER"
declare unprivileged_group="${USER/nobody/nogroup}"

export PS1='\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]'

ensure-paths() {
	mkdir -p \
		"$app_path" \
		"$env_path" \
		"$build_path" \
		"$cache_path" \
		"$buildpack_path"
}

paths() {
	declare desc="Shows path settings"
	printf "%-32s # %s\n" \
		"APP_PATH=$app_path" 		"Application path during runtime" \
		"ENV_PATH=$env_path" 		"Path to files for defining base environment" \
		"BUILD_PATH=$build_path" 	"Working directory during builds" \
		"CACHE_PATH=$cache_path" 	"Buildpack cache location" \
		"IMPORT_PATH=$import_path" 	"Mounted path to copy to app path" \
		"BUILDPACK_PATH=$buildpack_path" "Path to installed buildpacks"
}

version() {
	declare desc="Show version and supported version info"
	echo "herokuish: ${HEROKUISH_VERSION:-dev}"
	echo "buildpacks:"
	asset-cat include/buildpacks.txt | sed 's/.*heroku\///' | xargs printf "  %-26s %s\n"
}

title() {
	echo $'\e[1G----->' $*
}

indent() {
	while read line; do
		if [[ "$line" == --* ]] || [[ "$line" == ==* ]]; then
			echo $'\e[1G'$line
		else
			echo $'\e[1G      ' "$line"
		fi
	done
}

herokuish-test() {
	declare desc="Test running an app through Herokuish"
	declare path="${1:-/}" expected="$2"
	export PORT=5678
	echo "::: BUILDING APP :::"
	buildpack-build
	echo "::: STARTING WEB :::"
	procfile-start web &
	for retry in $(seq 1 10); do
		sleep 1 && nc -z -w 5 localhost $PORT && break
	done
	echo "::: CHECKING APP :::"
	local output
	output="$(curl --fail --retry 3 -v -s localhost:${PORT}$path)"
	if [[ "$expected" ]]; then
		sleep 1
		echo "::: APP OUTPUT :::"
		echo -e "$output"
		if [[ "$output" != "$expected" ]]; then
			echo "::: TEST FAILED :::"
			exit 2
		fi
	fi
	echo "::: TEST FINISHED :::"
}


herokuish() {
	set -eo pipefail; [[ "$TRACE" ]] && set -x

	if [[ -d "$import_path" ]]; then
		rm -rf "$app_path" && cp -r "$import_path" "$app_path"
	fi

	cmd-export paths
	cmd-export version
	cmd-export herokuish-test test

	cmd-export-ns buildpack "Use and install buildpacks"
	cmd-export buildpack-build
	cmd-export buildpack-install
	cmd-export buildpack-list

	cmd-export-ns slug "Manage application slugs"
	cmd-export slug-import
	cmd-export slug-generate
	cmd-export slug-export

	cmd-export-ns procfile "Use Procfiles and run app commands"
	cmd-export procfile-start
	cmd-export procfile-exec
	cmd-export procfile-parse

	case "$SELF" in
		/start)		procfile-start "$@";;
		/exec)		procfile-exec "$@";;
		/build)		buildpack-build;;
		*)			cmd-ns "" "$@";
	esac
}
