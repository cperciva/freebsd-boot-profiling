#!/usr/bin/env perl

# Suck in the data, accumulating the time spent and the integral of
# the time while it is being spent in each stack.
$LTSC=0;
while (<>) {
	chomp;
	/^([0-9]+) (.*)$/;
	$TSC=$1;
	$STACK=$2;
	if ($LTSC > 0) {
		$TSELF{$LSTACK} += $TSC - $LTSC;
		$T{$LSTACK} = $TSELF{$LSTACK};
		$T2{$LSTACK} += ($TSC - $LTSC) * ($TSC + $LTSC) / 2;
	}
	$LTSC=$TSC;
	$LSTACK=$STACK
}

# Compute the average timestamp spent in each stack.
@stacks=keys %T;
for $STACK (@stacks) {
	$TASELF{$STACK} = $T2{$STACK} / $TSELF{$STACK};
}

# Working from longest to shortest stack strings, add the time and
# integrated time spent in child stacks to their parents.  For each
# stack, compute the average timestamp spent in or under that stack.
@stacks=sort { -(length($a) <=> length($b)) } @stacks;
for $STACK (@stacks) {
	$P = $STACK;
	if ($P =~ s/;[^;]+$//) {
		$CHILDREN{$P}{$STACK} = 1;
		$T{$P} += $T{$STACK};
		$T2{$P} += $T2{$STACK};
	} else {
		$ROOTS{$STACK} = 1;
	}
	$TA{$STACK} = $T2{$STACK} / $T{$STACK};
}

# Make a depth first traversal of the tree, hitting nodes and printing
# stacks in order of the average timestamp spent in that subtree.
sub descend {
	local @stacks;
	@stacks = sort { ($TA{$a} <=> $TA{$b}) } @_;
	for $STACK (@stacks) {
		if (! $DESCENDED{$STACK}) {
			$DESCENDED{$STACK} = 1;
			$TA{$STACK} = $TASELF{$STACK};
			descend ($STACK, keys %{$CHILDREN{$STACK}});
		} else {
			print "$STACK $TSELF{$STACK}\n";
		}
	}
}
descend (keys %ROOTS);
