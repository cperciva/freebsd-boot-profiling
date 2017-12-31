#!/bin/sh

perl -e '
	while (<>) {
		chomp;
		if (/;DELAY /) {
			$DELAY=";DELAY";
			s/;DELAY / /;
		} else {
			$DELAY="";
		}
		s/.*;//;
		/^(.*) ([0-9]+)$/;
		$T{"$1$DELAY"} += $2;
	}
	for $k (keys %T) {
		printf "%d %s\n", $T{$k}, $k;
	}' |
    sort -rn
