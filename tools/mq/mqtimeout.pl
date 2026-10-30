# mqtimeout.pl SECONDS command...: exit 124 on timeout. Runs the command in its
# own process group; TERM to this process takes the whole group down.
my $secs = shift;
my $pid = fork();
die "fork: $!" unless defined $pid;
if ($pid == 0) { setpgrp(0, 0); exec { $ARGV[0] } @ARGV; exit 127; }
my $stop = sub { kill "TERM", -$pid; sleep 2; kill "KILL", -$pid; };
$SIG{TERM} = sub { $stop->(); exit 143; };
$SIG{INT}  = $SIG{TERM};
$SIG{ALRM} = sub { $stop->(); exit 124; };
alarm $secs;
waitpid($pid, 0);
exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
