# Simple `podman run` arg handler executed inside chroot
set -eu

work_dir=""
cmd_args=""
function parse_args() {
  local arg;
  local val_used;

  # Ensure we have a 'run' invocation
  arg="$1"
  if [[ $arg != run ]]; then
    echo "fakepodman only supports 'run', not ($1)"
    return 1
  fi
  shift # consume arg

  while [[ $# -gt 0 ]]; do
    arg="$1"
    val_used=''
    if [[ -z $arg ]]; then # Sanity
      echo "Unexpected empty argument"
      return 1
    fi

    # The args
    if [[ $arg = --rm ]]; then
      :
    elif [[ $arg = -v || $arg = -e ]]; then
      val_used=1
    elif [[ $arg = -w ]]; then
      work_dir="${2:-}"
      val_used=1
    else
      shift # consume image arg
      cmd_args="$@"
      return 0
    fi

    if [[ -n $val_used ]]; then
      shift # consume val
    fi

    shift # consume arg
  done
}

parse_args "$@"

export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export LD_LIBRARY_PATH=/opt/rust/lib:/usr/lib

if [[ -n $work_dir ]]; then
  cd "$work_dir"
fi

eval "$cmd_args"
