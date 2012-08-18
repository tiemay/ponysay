#!/usr/bin/env bash

VERSION=1.4.1



# Get bash script directory's parent
INSTALLDIR="$(dirname $( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"

# Directory for installed media files
SYSTEMSHARE="$INSTALLDIR/share/ponysay"
HOMESHARE="${HOME}/.local/share/ponysay"

# Subscripts
listcmd="$INSTALLDIR/lib/ponysay/list.pl"
linklistcmd="$INSTALLDIR/lib/ponysay/linklist.pl"
truncatercmd="$INSTALLDIR/lib/ponysay/truncater"
quotecmd="$INSTALLDIR/lib/ponysay/pq4ps"
qlistcmd="$INSTALLDIR/lib/ponysay/pq4ps-list.pl"

pony="*"  # Selected pony
wrap=""   # Message wrap column
ponies=() # Selected ponies

scrw=`(stty size <&2 || echo 0 0) | cut -d ' ' -f 2` # Screen width
scrh=`(stty size <&2 || echo 0 0) | cut -d ' ' -f 1` # Screen height

# KMS ponies extension
kmscmd=""
[ "$TERM" = "linux" ] && kmscmd=$(for c in $(echo $PATH":" | sed -e 's/:/\/ponysay2kmsponysay /g'); do if [ -f $c ]; then echo $c; break; fi done)
[ ! "$kmscmd" = "" ] && TERM="-linux-"

# Directories for installed ponies files
if [ "$TERM" = "linux" ]; then
	SYSTEMPONIES="$SYSTEMSHARE/ttyponies"
	HOMEPONIES="$HOMESHARE/ttyponies"
else
	SYSTEMPONIES="$SYSTEMSHARE/ponies"
	HOMEPONIES="$HOMESHARE/ponies"
fi

# Cowsay script
if [ ${0} == *ponythink ]; then
	if [ "$PONYSAY_COWTHINK" = "" ]; then
		cmd=cowthink
		customcmd=0
	else
		cmd="$PONYSAY_COWTHINK"
		customcmd=1
	fi
else
	if [ "$PONYSAY_COWSAY" = "" ]; then
		cmd=cowsay
		customcmd=0
	else
		cmd="$PONYSAY_COWSAY"
		customcmd=1
	fi
fi



# Pony quotes
ponyquotes() {
	[ "$TERM" = "-linux-" ] && TERM="linux"
	"$0" ${wrap:+-W$wrap} $("$quotecmd" $@)
}

# Function for printing the ponies and the message
say() {
	# Ponies use UTF-8 drawing characters. Prevent a Perl warning.
	export PERL_UNICODE=S

	# Clear screen in TTY
	( [ "$TERM" = "linux" ] || [ "$TERM" = "-linux-" ] ) && echo -ne '\e[H\e[2J'

	# Set PONYSAY_SHELL_LINES to default if not specified
	[ "$PONYSAY_SHELL_LINES" = "" ] && PONYSAY_SHELL_LINES=2

	# Width trunction
	function wtrunc {
		if [ "$PONYSAY_FULL_WIDTH" = 'yes' ] || [ "$PONYSAY_FULL_WIDTH" = 'y' ] || [ "$PONYSAY_FULL_WIDTH" = '1' ]; then
			cat
		else
			if [ -f $truncatercmd ]; then
				$truncatercmd $scrw
			else
				cat
			fi
		fi
	}

	# Height trunction, show top
	function htrunchead {
		head --lines=$(( $scrh - $PONYSAY_SHELL_LINES ))
	}

	# Height trunction, show bottom
	function htrunctail {
		tail --lines=$(( $scrh - $PONYSAY_SHELL_LINES ))
	}

	# Simplification of customisation of cowsay
	if [ $customcmd = 0 ]; then
		function cowcmd {
			pcmd='#!/usr/bin/perl\nuse utf8;'
			ccmd=$(for c in $(echo $PATH":" | sed -e 's/:/\/'"$cmd"' /g'); do if [ -f $c ]; then echo $c; break; fi done)
			
			if [ ${0} == *ponythink ]; then
				cat <(echo -e $pcmd) $ccmd > "/tmp/ponythink"
				perl '/tmp/ponythink' "$@"
				rm '/tmp/ponythink'
			else
				perl <(cat <(echo -e $pcmd) $ccmd) "$@"
			fi
		}
	else
		function cowcmd	{
			$cmd "$@"
		}
	fi

	# KMS ponies support
	if [ "$kmscmd" = "" ]; then
		function runcmd {
			cowcmd -f "$pony" "$@"
		}
	else
		function runcmd {
			cowcmd -f <($kmscmd "$pony") "$@"
		}
	fi

	# Print the pony and the message
	if [ "$TERM" = "linux" ] || [ "$PONYSAY_TRUNCATE_HEIGHT" = 'yes' ] || [ "$PONYSAY_TRUNCATE_HEIGHT" = 'y' ] || [ "$PONYSAY_TRUNCATE_HEIGHT" = '1' ]; then
		if [ "$PONYSAY_BOTTOM" = 'yes' ] || [ "$PONYSAY_BOTTOM" = 'y' ] || [ "$PONYSAY_BOTTOM" = '1' ]; then
		        runcmd "${wrap:+-W$wrap}" | wtrunc | htrunctail
		else
		        runcmd "${wrap:+-W$wrap}" | wtrunc | htrunchead
		fi
	else
		runcmd "${wrap:+-W$wrap}" | wtrunc
	fi
}



# If no stdin and no arguments then print usage and exit
if [ -t 0 ] && [ $# == 0 ]; then
	usage
	exit
fi



# Parse options
while getopts "f:W:Llhvq" OPT; do
	case ${OPT} in
		v)  version; exit ;;
		h)  usage; exit ;;
		f)  ponies+=( $OPTARG ) ;;
		l)  list; exit ;;
		L)  linklist; exit ;;
		W)  wrap="$OPTARG" ;;
		q)  shift $((OPTIND - 1)); ponyquotes "$*"; exit ;;
		\?) usage >&2; exit 1 ;;
	esac
done
shift $((OPTIND - 1))


# Check for cowsay
hash $cmd &>/dev/null; if [ $? -ne 0 ]; then
	cat >&2 <<EOF
You don't seem to have the $cmd program.
Please install it in order to use this wrapper.

Alternatively, symlink it to '$cmd' in anywhere in \$PATH
if it actually exists under a different filename.
EOF
	exit 1
fi


# Select random pony for the set of -f arguments
if [ ! ${#ponies[@]} == 0 ]; then
	pony="${ponies[$RANDOM%${#ponies[@]}]}"
fi


# Pony not a file? Search for it
if [ ! -f $pony ]; then
	ponies=()
	[ -d $SYSTEMPONIES ] && ponies+=( "$SYSTEMPONIES"/$pony.pony )
	[ -d $HOMEPONIES ]   && ponies+=( "$HOMEPONIES"/$pony.pony )
	
	if (( ${#ponies} < 1 )); then
		echo >&2 "All the ponies are missing! Call the Princess!"
		exit 1
	fi
	
	# Choose a random pony
	pony="${ponies[$RANDOM%${#ponies[@]}]}"
fi


# Print pony with message
if [ -n "$*" ]; then
	# Handle a message given via arguments
	say <<<"$*"
else
	# Handle a message given in stdin
	say
fi

