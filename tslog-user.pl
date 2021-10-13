#!/usr/bin/env perl

# Subroutine for recursively printing timestamped "stacks".
sub stack {
	my $above = shift();
	my $pid = shift();
	my $tsc = $tscs{$pid};
	print "$tscs{$pid} $above;$pid $pname{$pid}\n";
	for $child (sort {$a <=> $b} keys %{$children{$pid}}) {
		$tscs{$child} = $tsc + 1 if ($tscs{$child} <= $tsc);
		next if $tsce{$child} < $tscs{$child};
		stack("$above;$pid $pname{$pid}", $child);
		$tsc = $tsce{$child};
	}
	print "$tsce{$pid} $above\n";
}

# Slurp everything in
while (<>) {
	next if $_ =~ /^$/;
	die "Invalid line: \"$_\"" unless $_ =~ /^([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) "(.*)" "(.*)"$/;
	next if ($3 == 0);
	$ppid{$1} = $2;
	$tscs{$1} = $3;
	$tsce{$1} = $4;
	$exec{$1} = $5;
	$namei{$1} = $6;
}

# Get a sorted list of pids to make life easier later.
@pids = sort {$a <=> $b} keys %ppid;

# Find the first process spawned by init; that's rc.
for $pid (@pids) {
	if ($ppid{$pid} == 1) {
		$rcpid = $pid;
		last;
	}
}
die "Can't find rc's pid" if ! defined($rcpid);

# Hack: Set init's start time to 1 cycle before rc is forked,
# since the creation time for the process is actually long
# before it starts running.
$tscs{1} = $tscs{$rcpid} - 1;

# Assign names to processes:
# If it called exec, that's its name.
# Otherwise if it's a child of rc, use the first path it looked up.
# Otherwise use its parent's name.
for $pid (@pids) {
	if ($exec{$pid} ne "") {
		$pname{$pid} = $exec{$pid};
	} elsif ($ppid{$pid} == $rcpid) {
		$pname{$pid} = $namei{$pid};
	} else {
		$pname{$pid} = $pname{$ppid{$pid}};
	}
}

# Hack: Set rc's process name to "/etc/rc" even though it was
# executed as "sh".
$pname{$rcpid} = "/etc/rc";

# Adjust end times of processes: Mark a process as having completed
# no later than its parent.  If a process is still running beyond
# that point, it's presumably not holding up the boot process.
for $pid (@pids) {
	next if $tsce{$ppid{$pid}} == 0;
	print "truncating tsce of $pid\n" if ($tsce{$pid} > $tsce{$ppid{$pid}});
	$tsce{$pid} = $tsce{$ppid{$pid}} if ($tsce{$pid} > $tsce{$ppid{$pid}});
}

# Collect sets of children
for $pid (@pids) {
	$children{$ppid{$pid}}{$pid} = 1;
}

# Output timestamped "stacks"
print "$tscs{1} 1 $pname{1}\n";
stack("1 $pname{1}", $rcpid);
