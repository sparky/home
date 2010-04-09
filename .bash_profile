# .bash_profile - file executed when logging in

# execute local (and so system wide) rc file only when interactive (not from scp etc.)
# bash is too dumb to do in on it's own when started as login shell
if [[ $- = *i* ]] && [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

export HISTSIZE=1000
export HISTFILESIZE=1000
export TMP=~/tmp
export TMPDIR="$TMP"

HOME2=/home/users/sparky
[ $HOME != $HOME2 -a -d $HOME2 ] && export HOME2

# setup LOCALE variables
export LANGUAGE="ca_ES:es_ES"
export LANG="ca_ES.UTF-8"

export VISUAL=vim
LOCALBIN="";
[ -n "$(ls /usr/local/bin/)" ] && LOCALBIN="/usr/local/bin/:"
export PATH="$HOME/bin:$LOCALBIN/usr/bin:/bin"

# only You can access your files
#umask 077

# turn off accept of 'wall' and 'write':
[ ! -x /usr/bin/mesg ] || mesg n
