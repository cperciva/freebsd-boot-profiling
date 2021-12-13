#!/bin/sh

TSCSTART=`sysctl -n debug.tslog | head -1 | cut -f 2 -d ' '`
TSCEND=`sysctl -n debug.tslog_user | grep sh | head -1 | cut -f 4 -d ' '`
case `uname -p` in
amd64)
	TSCFREQ=`sysctl -n machdep.tsc_freq`
	;;
arm64)
	TSCFREQ=`sysctl -n "kern.timecounter.tc.ARM MPCore Timecounter.frequency"`
	;;
*)
	echo "Unsupported platform"
	exit 1
	;;
esac

MS=$(((TSCEND - TSCSTART) * 1000 / TSCFREQ));

sh tslog.sh |
    perl stackcollapse-tslog.pl |
    perl flamechart.pl -flamechart -colors tslog --hash \
	--title "`uname -r | cut -f 1-2 -d -` boot" \
	--subtitle "$MS ms" \
	--width $((MS / 20))
