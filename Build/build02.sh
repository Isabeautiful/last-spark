#!/bin/sh
printf '\033c\033]0;%s\a' LastSpark
base_path="$(dirname "$(realpath "$0")")"
"$base_path/build02.x86_64" "$@"
