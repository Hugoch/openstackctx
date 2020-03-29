#!/bin/bash

# Default values for the prompt
# Override these values in ~/.zshrc or ~/.bashrc
OPENSTACK_PS1_BINARY="${OPENSTACK_PS1_BINARY:-openstackctxcli}"
OPENSTACK_PS1_SYMBOL_ENABLE="${OPENSTACK_PS1_SYMBOL_ENABLE:-false}"
OPENSTACK_PS1_SYMBOL_DEFAULT=${OPENSTACK_PS1_SYMBOL_DEFAULT:-$'\u1F3F7 '}
OPENSTACK_PS1_SYMBOL_USE_IMG="${OPENSTACK_PS1_SYMBOL_USE_IMG:-false}"
OPENSTACK_PS1_CONTEXT_ENABLE="${OPENSTACK_PS1_CONTEXT_ENABLE:-true}"
OPENSTACK_PS1_PREFIX="${OPENSTACK_PS1_PREFIX-(}"
OPENSTACK_PS1_SEPARATOR="${OPENSTACK_PS1_SEPARATOR-|}"
OPENSTACK_PS1_DIVIDER="${OPENSTACK_PS1_DIVIDER-:}"
OPENSTACK_PS1_SUFFIX="${OPENSTACK_PS1_SUFFIX-)}"
OPENSTACK_PS1_SYMBOL_COLOR="${OPENSTACK_PS1_SYMBOL_COLOR-blue}"
OPENSTACK_PS1_CTX_COLOR="${OPENSTACK_PS1_CTX_COLOR-red}"
OPENSTACK_PS1_NS_COLOR="${OPENSTACK_PS1_NS_COLOR-cyan}"
OPENSTACK_PS1_BG_COLOR="${OPENSTACK_PS1_BG_COLOR}"
OPENSTACK_PS1_OPENSTACKCONFIG_CACHE="${OPENSTACKCONFIG}"
OPENSTACK_PS1_DISABLE_PATH="${HOME}/.openstack/openstack-ps1/disabled"
OPENSTACK_PS1_LAST_TIME=0
OPENSTACK_PS1_CLUSTER_FUNCTION="${OPENSTACK_PS1_CLUSTER_FUNCTION}"
OPENSTACK_PS1_NAMESPACE_FUNCTION="${OPENSTACK_PS1_NAMESPACE_FUNCTION}"

# Determine our shell
if [ "${ZSH_VERSION-}" ]; then
  OPENSTACK_PS1_SHELL="zsh"
elif [ "${BASH_VERSION-}" ]; then
  OPENSTACK_PS1_SHELL="bash"
fi

_openstack_ps1_init() {
  [[ -f "${OPENSTACK_PS1_DISABLE_PATH}" ]] && OPENSTACK_PS1_ENABLED=off

  case "${OPENSTACK_PS1_SHELL}" in
  "zsh")
    _OPENSTACK_PS1_OPEN_ESC="%{"
    _OPENSTACK_PS1_CLOSE_ESC="%}"
    _OPENSTACK_PS1_DEFAULT_BG="%k"
    _OPENSTACK_PS1_DEFAULT_FG="%f"
    setopt PROMPT_SUBST
    autoload -U add-zsh-hook
    add-zsh-hook precmd _openstack_ps1_update_cache
    zmodload -F zsh/stat b:zstat
    zmodload zsh/datetime
    ;;
  "bash")
    _OPENSTACK_PS1_OPEN_ESC=$'\001'
    _OPENSTACK_PS1_CLOSE_ESC=$'\002'
    _OPENSTACK_PS1_DEFAULT_BG=$'\033[49m'
    _OPENSTACK_PS1_DEFAULT_FG=$'\033[39m'
    [[ $PROMPT_COMMAND =~ _openstack_ps1_update_cache ]] || PROMPT_COMMAND="_openstack_ps1_update_cache;${PROMPT_COMMAND:-:}"
    ;;
  esac

  _openstack_ps1_get_context
  OPENSTACK_ENV_VARIABLES="$(${OPENSTACK_PS1_BINARY} activate "${OPENSTACK_PS1_CONTEXT}")"
  retCode=$?
  if [ $retCode -eq 0 ]; then
    eval "${OPENSTACK_ENV_VARIABLES}"
  fi
}

_openstack_ps1_color_fg() {
  local OPENSTACK_PS1_FG_CODE
  case "${1}" in
  black) OPENSTACK_PS1_FG_CODE=0 ;;
  red) OPENSTACK_PS1_FG_CODE=1 ;;
  green) OPENSTACK_PS1_FG_CODE=2 ;;
  yellow) OPENSTACK_PS1_FG_CODE=3 ;;
  blue) OPENSTACK_PS1_FG_CODE=4 ;;
  magenta) OPENSTACK_PS1_FG_CODE=5 ;;
  cyan) OPENSTACK_PS1_FG_CODE=6 ;;
  white) OPENSTACK_PS1_FG_CODE=7 ;;
  # 256
  [0-9] | [1-9][0-9] | [1][0-9][0-9] | [2][0-4][0-9] | [2][5][0-6]) OPENSTACK_PS1_FG_CODE="${1}" ;;
  *) OPENSTACK_PS1_FG_CODE=default ;;
  esac

  if [[ "${OPENSTACK_PS1_FG_CODE}" == "default" ]]; then
    OPENSTACK_PS1_FG_CODE="${_OPENSTACK_PS1_DEFAULT_FG}"
    return
  elif [[ "${OPENSTACK_PS1_SHELL}" == "zsh" ]]; then
    OPENSTACK_PS1_FG_CODE="%F{$OPENSTACK_PS1_FG_CODE}"
  elif [[ "${OPENSTACK_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &>/dev/null; then
      OPENSTACK_PS1_FG_CODE="$(tput setaf ${OPENSTACK_PS1_FG_CODE})"
    elif [[ $OPENSTACK_PS1_FG_CODE -ge 0 ]] && [[ $OPENSTACK_PS1_FG_CODE -le 256 ]]; then
      OPENSTACK_PS1_FG_CODE="\033[38;5;${OPENSTACK_PS1_FG_CODE}m"
    else
      OPENSTACK_PS1_FG_CODE="${_OPENSTACK_PS1_DEFAULT_FG}"
    fi
  fi
  echo ${_OPENSTACK_PS1_OPEN_ESC}${OPENSTACK_PS1_FG_CODE}${_OPENSTACK_PS1_CLOSE_ESC}
}

_openstack_ps1_color_bg() {
  local OPENSTACK_PS1_BG_CODE
  case "${1}" in
  black) OPENSTACK_PS1_BG_CODE=0 ;;
  red) OPENSTACK_PS1_BG_CODE=1 ;;
  green) OPENSTACK_PS1_BG_CODE=2 ;;
  yellow) OPENSTACK_PS1_BG_CODE=3 ;;
  blue) OPENSTACK_PS1_BG_CODE=4 ;;
  magenta) OPENSTACK_PS1_BG_CODE=5 ;;
  cyan) OPENSTACK_PS1_BG_CODE=6 ;;
  white) OPENSTACK_PS1_BG_CODE=7 ;;
  # 256
  [0-9] | [1-9][0-9] | [1][0-9][0-9] | [2][0-4][0-9] | [2][5][0-6]) OPENSTACK_PS1_BG_CODE="${1}" ;;
  *) OPENSTACK_PS1_BG_CODE=$'\033[0m' ;;
  esac

  if [[ "${OPENSTACK_PS1_BG_CODE}" == "default" ]]; then
    OPENSTACK_PS1_FG_CODE="${_OPENSTACK_PS1_DEFAULT_BG}"
    return
  elif [[ "${OPENSTACK_PS1_SHELL}" == "zsh" ]]; then
    OPENSTACK_PS1_BG_CODE="%K{$OPENSTACK_PS1_BG_CODE}"
  elif [[ "${OPENSTACK_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &>/dev/null; then
      OPENSTACK_PS1_BG_CODE="$(tput setab ${OPENSTACK_PS1_BG_CODE})"
    elif [[ $OPENSTACK_PS1_BG_CODE -ge 0 ]] && [[ $OPENSTACK_PS1_BG_CODE -le 256 ]]; then
      OPENSTACK_PS1_BG_CODE="\033[48;5;${OPENSTACK_PS1_BG_CODE}m"
    else
      OPENSTACK_PS1_BG_CODE="${DEFAULT_BG}"
    fi
  fi
  echo ${OPEN_ESC}${OPENSTACK_PS1_BG_CODE}${CLOSE_ESC}
}

_openstack_ps1_binary_check() {
  command -v $1 >/dev/null
}

_openstack_ps1_symbol() {
  [[ "${OPENSTACK_PS1_SYMBOL_ENABLE}" == false ]] && return

  case "${OPENSTACK_PS1_SHELL}" in
  bash)
    if ((BASH_VERSINFO[0] >= 4)) && [[ $'\u1F3F7 ' != "\\u1F3F7 " ]]; then
      OPENSTACK_PS1_SYMBOL="${OPENSTACK_PS1_SYMBOL_DEFAULT}"
      OPENSTACK_PS1_SYMBOL=$'\u1F3F7 '
      OPENSTACK_PS1_SYMBOL_IMG=$'\u1F3F7 '
    else
      OPENSTACK_PS1_SYMBOL=$'\xF0\x9F\x8F\xB7 '
      OPENSTACK_PS1_SYMBOL_IMG=$'\xF0\x9F\x8F\xB7 '
    fi
    ;;
  zsh)
    OPENSTACK_PS1_SYMBOL="${OPENSTACK_PS1_SYMBOL_DEFAULT}"
    OPENSTACK_PS1_SYMBOL_IMG="\u1F3F7 "
    ;;
  *)
    OPENSTACK_PS1_SYMBOL="openstack"
    ;;
  esac

  if [[ "${OPENSTACK_PS1_SYMBOL_USE_IMG}" == true ]]; then
    OPENSTACK_PS1_SYMBOL="${OPENSTACK_PS1_SYMBOL_IMG}"
  fi

  echo "${OPENSTACK_PS1_SYMBOL}"
}

_openstack_ps1_split() {
  type setopt >/dev/null 2>&1 && setopt SH_WORD_SPLIT
  local IFS=$1
  echo $2
}

_openstack_ps1_file_newer_than() {
  local mtime
  local file=$1
  local check_time=$2

  if [[ "${OPENSTACK_PS1_SHELL}" == "zsh" ]]; then
    mtime=$(zstat -L +mtime "${file}")
  elif stat -c "%s" /dev/null &>/dev/null; then
    # GNU stat
    mtime=$(stat -L -c %Y "${file}")
  else
    # BSD stat
    mtime=$(stat -L -f %m "$file")
  fi

  [[ "${mtime}" -gt "${check_time}" ]]
}

_openstack_ps1_update_cache() {
  local return_code=$?

  [[ "${OPENSTACK_PS1_ENABLED}" == "off" ]] && return $return_code

  if ! _openstack_ps1_binary_check "${OPENSTACK_PS1_BINARY}"; then
    # No ability to fetch context/namespace; display N/A.
    OPENSTACK_PS1_CONTEXT="BINARY-N/A"
    OPENSTACK_PS1_NAMESPACE="N/A"
    return
  fi

  if [[ "${OPENSTACKCONFIG}" != "${OPENSTACK_PS1_OPENSTACKCONFIG_CACHE}" ]]; then
    # User changed OPENSTACKCONFIG; unconditionally refetch.
    OPENSTACK_PS1_OPENSTACKCONFIG_CACHE=${OPENSTACKCONFIG}
    _openstack_ps1_get_context
    return
  fi

  # openstackctl will read the environment variable $OPENSTACKCONFIG
  # otherwise set it to ~/.openstack/config
  local conf
  for conf in $(_openstack_ps1_split : "${OPENSTACKCONFIG:-${HOME}/.openstack/config}"); do
    [[ -r "${conf}" ]] || continue
    if _openstack_ps1_file_newer_than "${conf}" "${OPENSTACK_PS1_LAST_TIME}"; then
      _openstack_ps1_get_context
      return
    fi
  done

  return $return_code
}

_openstack_ps1_get_context() {
  # Set the command time
  if [[ "${OPENSTACK_PS1_SHELL}" == "bash" ]]; then
    if ((BASH_VERSINFO[0] >= 4 && BASH_VERSINFO[1] >= 2)); then
      OPENSTACK_PS1_LAST_TIME=$(printf '%(%s)T')
    else
      OPENSTACK_PS1_LAST_TIME=$(date +%s)
    fi
  elif [[ "${OPENSTACK_PS1_SHELL}" == "zsh" ]]; then
    OPENSTACK_PS1_LAST_TIME=$EPOCHSECONDS
  fi

  if [[ "${OPENSTACK_PS1_CONTEXT_ENABLE}" == true ]]; then
    OPENSTACK_PS1_CONTEXT="$(${OPENSTACK_PS1_BINARY} current-context 2>/dev/null)"
    # Set namespace to 'N/A' if it is not defined
    OPENSTACK_PS1_CONTEXT="${OPENSTACK_PS1_CONTEXT:-N/A}"

    if [[ ! -z "${OPENSTACK_PS1_CLUSTER_FUNCTION}" ]]; then
      OPENSTACK_PS1_CONTEXT=$($OPENSTACK_PS1_CLUSTER_FUNCTION $OPENSTACK_PS1_CONTEXT)
    fi
  fi
}

# Set openstack-ps1 shell defaults
_openstack_ps1_init

_openstackon_usage() {
  cat <<"EOF"
Toggle openstack-ps1 prompt on
Usage: openstackon [-g | --global] [-h | --help]
With no arguments, turn on openstack-ps1 status for this shell instance (default).
  -g --global  turn on openstack-ps1 status globally
  -h --help    print this message
EOF
}

_openstackoff_usage() {
  cat <<"EOF"
Toggle openstack-ps1 prompt off
Usage: openstackoff [-g | --global] [-h | --help]
With no arguments, turn off openstack-ps1 status for this shell instance (default).
  -g --global turn off openstack-ps1 status globally
  -h --help   print this message
EOF
}

openstackon() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _openstackon_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f -- "${OPENSTACK_PS1_DISABLE_PATH}"
  elif [[ "$#" -ne 0 ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _openstackon_usage
    return
  fi

  OPENSTACK_PS1_ENABLED=on
}

openstackoff() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _openstackoff_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p -- "$(dirname "${OPENSTACK_PS1_DISABLE_PATH}")"
    touch -- "${OPENSTACK_PS1_DISABLE_PATH}"
  elif [[ $# -ne 0 ]]; then
    echo "error: unrecognized flag ${1}" >&2
    _openstackoff_usage
    return
  fi

  OPENSTACK_PS1_ENABLED=off
}

openstack_ps1() {
  [[ "${OPENSTACK_PS1_ENABLED}" == "off" ]] && return
  [[ -z "${OPENSTACK_PS1_CONTEXT}" ]] && [[ "${OPENSTACK_PS1_CONTEXT_ENABLE}" == true ]] && return

  local OPENSTACK_PS1
  local OPENSTACK_PS1_RESET_COLOR="${_OPENSTACK_PS1_OPEN_ESC}${_OPENSTACK_PS1_DEFAULT_FG}${_OPENSTACK_PS1_CLOSE_ESC}"

  # Background Color
  [[ -n "${OPENSTACK_PS1_BG_COLOR}" ]] && OPENSTACK_PS1+="$(_openstack_ps1_color_bg ${OPENSTACK_PS1_BG_COLOR})"

  # Prefix
  [[ -n "${OPENSTACK_PS1_PREFIX}" ]] && OPENSTACK_PS1+="${OPENSTACK_PS1_PREFIX}"

  # Symbol
  OPENSTACK_PS1+="$(_openstack_ps1_color_fg $OPENSTACK_PS1_SYMBOL_COLOR)$(_openstack_ps1_symbol)${OPENSTACK_PS1_RESET_COLOR}"

  if [[ -n "${OPENSTACK_PS1_SEPARATOR}" ]] && [[ "${OPENSTACK_PS1_SYMBOL_ENABLE}" == true ]]; then
    OPENSTACK_PS1+="${OPENSTACK_PS1_SEPARATOR}"
  fi

  # Context
  if [[ "${OPENSTACK_PS1_CONTEXT_ENABLE}" == true ]]; then
    OPENSTACK_PS1+="$(_openstack_ps1_color_fg $OPENSTACK_PS1_CTX_COLOR)${OPENSTACK_PS1_CONTEXT}${OPENSTACK_PS1_RESET_COLOR}"
  fi

  # Suffix
  [[ -n "${OPENSTACK_PS1_SUFFIX}" ]] && OPENSTACK_PS1+="${OPENSTACK_PS1_SUFFIX}"

  # Close Background color if defined
  [[ -n "${OPENSTACK_PS1_BG_COLOR}" ]] && OPENSTACK_PS1+="${_OPENSTACK_PS1_OPEN_ESC}${_OPENSTACK_PS1_DEFAULT_BG}${_OPENSTACK_PS1_CLOSE_ESC}"

  echo "${OPENSTACK_PS1}"
}

openstackctx() {
  OPENSTACK_ENV_VARIABLES="$(${OPENSTACK_PS1_BINARY})"
  retCode=$?
  if [ $retCode -eq 0 ]; then
    eval "${OPENSTACK_ENV_VARIABLES}"
  fi
}
