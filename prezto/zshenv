#
# Defines environment variables.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ "$SHLVL" -eq 1 && ! -o LOGIN && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

### ASML
export DYLD_LIBRARY_PATH=/opt/oracle/instantclient_11_2:$DYLD_LIBRARY_PATH
export ORACLE_HOME=/opt/oracle/instantclient_11_2
export NSLANG="AMERICAN_AMERICA.UTF8"
export PATH=/opt/oracle/instantclient_11_2:$PATH
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export NLS_LANG=AMERICAN_AMERICA.UTF8

AUTOSUGGESTION_ACCEPT_RIGHT_ARROW=1

# Perl
export PERL_MB_OPT="--install_base \"/Users/etienne/perl5\""; export PERL_MB_OPT;
export PERL_MM_OPT="INSTALL_BASE=/Users/etienne/perl5"; export PERL_MM_OPT;