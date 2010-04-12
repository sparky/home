# .bashrc - startup file for bash as interactive shell

if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

setps() {
local b='\[\033[1m\]'
local R='\[\033[31m\]'
local G='\[\033[32m\]'
local B='\[\033[34m\]'
local W='\[\033[37m\]'
local e='\[\033[0m\]'
PS1="$b[$R\u$e@$b$G\h $B\W$W]\$$e "
PS2='\[\033[4;5m\]>\[\033[0m\] '
PS4='\[\033[5m\]+\[\033[0m\] '
}
setps
unset setps

[ $TERM == xterm ] && export TERM=xterm-256color

# Put your local functions and aliases here
alias google='perl -le "use URI::Escape; exec \"elinks\", \"http://www.google.com/search?q=\" . uri_escape( join \" \", @ARGV )"'
alias t="terminal-open"
