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
export DYLD_LIBRARY_PATH=/opt/oracle/instantclient_11_2:$DYLD_LIBRARY_PATH
export ORACLE_HOME=/opt/oracle/instantclient_11_2
export NSLANG="AMERICAN_AMERICA.UTF8"
export PATH=/opt/oracle/instantclient_11_2:$PATH
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export NLS_LANG=AMERICAN_AMERICA.UTF8

# Accept autosuggestions using tab & right arrow
AUTOSUGGESTION_ACCEPT_RIGHT_ARROW=1
