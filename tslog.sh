#!/bin/sh

SRCDIR=`pwd`
WRKDIR=`mktemp -d -t tslog` || exit 1
cd $WRKDIR

sysctl -b debug.tslog > ts.log
LTSC=0
TSCOFFSET=0
while read TD TSC REST; do
	if [ $TSC -lt $LTSC ]; then
#		echo "Cycle count went backwards (from $LTSC to $TSC)!"
#		echo "Results may not be meaningful."
		TSCOFFSET=$((LTSC + TSCOFFSET - TSC))
	fi > /dev/stderr
	LTSC=$TSC
	NTSC=$((TSC + TSCOFFSET))
	echo "$TD $NTSC $REST"
done < ts.log > ts.log.tmp
mv ts.log.tmp ts.log
sort < ts.log > ts.log.sorted
cut -f 1 -d ' ' < ts.log | sort -u > threads
while read THREAD; do
	STACK="kernel"
	look $THREAD ts.log.sorted |
	    sort -nk2 |
	    while read TD TSC X F; do
		if [ "$X" = "ENTER" ]; then
			case "$F" in
			mi_startup|start_init)
				ln -sf tslog.thread.$THREAD tslog.thread.$F
				;;
			esac
			STACK="$STACK;$F"
		elif [ "$X" = "EXIT" ]; then
			if [ "$F" = "start_init" ]; then
				echo "$TSC" > tsc.end
			fi
			STACK=${STACK%;$F*}
		elif [ "$X" = "THREAD" ]; then
			echo "$TD $TSC THREAD $F"
			STACK="THREAD $F"
		else
			echo "$TD $TSC $X $F"
			continue;
		fi
		echo "$TD $TSC STACK $STACK"
	done > tslog.thread.$THREAD
done < threads
cat tslog.thread.0x0 | sed -e 's/kernel;//' > ts.log.accumulated
cat tslog.thread.mi_startup tslog.thread.start_init >> ts.log.accumulated
TSCEND=`cat tsc.end`
cat ts.log.accumulated |
    grep 'EVENT UNWAIT' |
    cut -f 5- -d ' ' |
    sort -u > waits
while read WAITER; do
	WAITING=""
	HOLDS=""
	grep -E "0x[0-9a-f]+ [0-9]+ (THREAD|EVENT (HOLD|RELEASE|WAIT|UNWAIT) $WAITER\$)" ts.log |
	    sort -rnk2 |
	    while read TD TSC EVENT TYPE TOPIC; do
		if [ "$EVENT $TYPE" = "EVENT UNWAIT" ]; then
			WAITING=$TSC
			continue
		fi
		if [ "$EVENT $TYPE" = "EVENT RELEASE" ]; then
			HOLDS="$HOLDS$TD $TSC "
			continue
		fi
		if [ "$EVENT" = "THREAD" ] ||
		    [ "$EVENT $TYPE" = "EVENT HOLD" ]; then
			case "$HOLDS" in
			$TD*)
				if [ "$WAITING" ]; then
					echo -n "$TSC $WAITING "
					echo "$HOLDS" | cut -f 1-2 -d ' '
					WAITING=$TSC
				fi
				HOLDS="${HOLDS#*$TD * }"
				;;
			*$TD*)
				HOLDS="${HOLDS%%$TD*}${HOLDS#*$TD * }"
				;;
			esac
			continue
		fi
		if [ "$EVENT $TYPE" = "EVENT WAIT" ] && [ "$HOLDS" ]; then
			echo -n "$TSC $WAITING "
			echo "$HOLDS" | cut -f 1-2 -d ' '
			WAITING=""
		fi
	done
done < waits |
    while read TSC1 TSC2 TD TSC3; do
	if [ $TSC2 -gt $TSC3 ]; then
		TSC2=$TSC3
	fi
	OREST=""
	while read TD1 TSC REST; do
		if [ $TSC -ge $TSC1 ] && [ "$OREST" ]; then
			echo "$TD1 $((TSC1 + 1)) $OREST"
			OREST=""
		fi
		if [ $TSC -lt $TSC1 ]; then
			case "$REST" in
			STACK*)
				OREST="$REST"
				;;
			esac
		fi
		if [ $TSC -ge $TSC1 ] && [ $TSC -lt $TSC2 ]; then
			echo "$TD1 $TSC $REST"
		fi
	done < tslog.thread.$TD
done >> ts.log.accumulated

cat ts.log.accumulated |
    sort -nk2 |
    while read TD TSC EVENT REST; do
	if [ "$TSC" -gt "$TSCEND" ]; then
		break;
	fi
	case $EVENT in
	STACK)
		LSTACK="$REST"
		echo "$TSC $STACKPREFIX$REST"
		;;
	EVENT)
		case "$REST" in
		WAIT*)
			STACKPREFIX="$LSTACK;"
			WAITTHREAD="$TD"
			;;
		UNWAIT*)
			echo "$TSC ${STACKPREFIX%;}"
			LSTACK="${STACKPREFIX%;}"
			STACKPREFIX=""
			;;
		esac
		;;
	esac
done

sysctl -n debug.tslog_user | perl $SRCDIR/tslog-user.pl

cat threads |
    lam -s "tslog.thread." - |
    xargs rm
rm tslog.thread.start_init tslog.thread.mi_startup
rm tsc.end ts.log ts.log.sorted ts.log.accumulated threads waits
cd .. && rmdir $WRKDIR
