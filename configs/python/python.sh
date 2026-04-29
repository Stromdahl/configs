# shellcheck shell=bash
# Python: virtualenvwrapper.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

export WORKON_HOME="$HOME/.virtualenvs"
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3

for _vew in /usr/share/virtualenvwrapper/virtualenvwrapper.sh \
            /usr/local/bin/virtualenvwrapper.sh; do
  [ -f "$_vew" ] && . "$_vew" && break
done
unset _vew
