#
# Defines environment variables.
#
#

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ "$SHLVL" -eq 1 && ! -o LOGIN && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

# Locale
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

### ASML
export NSLANG="AMERICAN_AMERICA.UTF8"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export NLS_LANG=AMERICAN_AMERICA.UTF8
