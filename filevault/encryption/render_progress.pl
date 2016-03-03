#!/usr/bin/perl
use Carp;

my $scale = shift;
my $bar_max = shift;
my $log_level = -5;

$bar_max = 200 unless defined $bar_max;

my ($last_pc, $max_pc) = (-1, 0);
my $ts;
while (<>) {
    chomp;
    $ts = $_ if /\d\d:\d\d:\d\d/;
    if (/^Encryption in progress:/ && /([\d.]+|Pending)$/) {
        my $pc = $1;
        $max_pc = $pc if $max_pc < $pc;
        log1(">> pc=$pc");

        my $apc = align_pc($pc);
        log1("apc=$apc");
        my $mapc = align_pc($max_pc);
        log1("mapc=$mapc");

        my $sc = defined($scale) ? $scale : best_scale($pc);
        $scale = $sc;
        log1("scale=$scale");

        my $pcs = scale_pc($pc, $sc);
        log1("pcs=$pcs");
        my $apcs = align_sc($pcs);
        log1("apcs=$apcs");

        my $bar = draw_bar($pcs);
        log1("    bar:$bar");
        $bar = grid_bar($bar, $sc);
        log1("gridbar:$bar");

        print "$ts: $apc/$mapc {$apcs/$bar_max}[$bar] *$sc\n" if $last_pc != $pc;
        $last_pc = $pc;
    }
}

sub log0 {
    my $msg = shift;
    print "#0:$msg\n" if 0 <= $log_level;
}
sub log1 {
    my $msg = shift;
    print "#1:$msg\n" if 1 <= $log_level;
}
sub log2 {
    my $msg = shift;
    print "#2:$msg\n" if 2 <= $log_level;
}

# scale percantage to integer [0 .. $bar_max]
sub scale_pc {
    my $pc = shift; # percentage
    my $sc = shift; # scale
    croak "ERROR: undefined pc" unless defined $pc;
    croak "ERROR: undefined sc"  unless defined $sc;
    croak "ERROR: pc=$pc" if $pc > 100;
    return int(($pc / 100) ** $sc * $bar_max);
}

# get distance between scaled left and right pc
sub get_dist {
    my $lpc = shift; # left percentage
    my $rpc = shift; # right percentage
    my $sc = shift;  # scale
    croak "ERROR: undefined lpc" unless defined $lpc;
    croak "ERROR: undefined rpc" unless defined $rpc;
    croak "ERROR: undefined sc" unless defined $sc;
    my $lps = scale_pc($lpc, $sc);
    my $rps = scale_pc($rpc, $sc);
    return $rps - $lps;
}

# rounds number to required precision
sub round_to {
    my $num = shift; # a number
    my $pre = shift; # precision (10, 100, ...)
    croak unless defined $num;
    croak unless defined $pre;
    return int($num * $pre + 0.5) / $pre;
}

# find best scale for pc
sub best_scale {
    my $pc = shift; # percentage
    croak "ERROR: undefined pc" unless defined $pc;
    croak "ERROR: pc=$pc" if $pc > 100;

    my $lpc = $pc > 10 ? $pc - 10 : 0;
    my $rpc = $lpc + 10;
    croak "ERROR: pc=$pc, lpc=$lpc, rpc=$rpc" if $lpc > $rpc || $lpc > $pc || $rpc < $pc;
    
    my ($lsc, $rsc) = (0, 10);
    my ($best_sc, $best_dt) = (0, 0);
    while ($rsc - $lsc > 0.1) {
        # current scale
        my $sc = round_to(($rsc - $lsc) / 2 + $lsc, 10);

        # candidate scales
	my $sc1 = round_to(($sc - $lsc) / 2 + $lsc, 10);
	my $sc2 = round_to(($rsc - $sc) / 2 + $sc, 10);

        # check if we have any progress
        last unless (abs($lsc - $sc1) > 0.1 || abs($rsc - $sc2) > 0.1);

        # candidate distances
        my $dt1 = get_dist($lpc, $rpc, $sc1);
        my $dt2 = get_dist($lpc, $rpc, $sc2);
        log2("pc=$pc, lpc=$lpc, rpc=$rpc, sc=$sc, sc1=$sc1, sc2=$sc2, dt1=$dt1, dt2=$dt2, lsc=$lsc, rsc=$rsc");

        # choose the best and make next turn
        if ($dt1 > $best_dt) {
            log2("<<");
            $best_dt = $dt1;
            $best_sc = $sc1;
            $rsc = $sc;
        }
        elsif ($dt2 > $best_dt) {
            log2(">>");
            $best_dt = $dt2;
            $best_sc = $sc2;
            $lsc = $sc;
        }
        else {
            log2("><");
            $best_dt = get_dist($lpc, $rpc, $sc);
            $best_sc = $sc;
            $lsc = $sc1;
            $rsc = $sc2;
        }
        log1("pc=$pc, best_sc=$best_sc, best_dt=$best_dt");
    }
    return $best_sc;
}

# align percentage to be 5 chars
sub align_pc {
    my $pc = shift; # percentage
    croak "ERROR: undefined pc" unless defined $pc;
    croak "ERROR: pc=$pc" if $pc > 100;
    $pc = '-' x 5 if length($pc) > 5;
    return ' ' x (5 - length($pc)) . $pc;
}

# align scale to be 3 chars
sub align_sc {
    my $sc = shift; # scale
    croak "ERROR: undefined sc" unless defined $sc;
    return '0' x (3 - length($sc)) . $sc;
}

# draw a bar from scale value of [0 .. $bar_max]
sub draw_bar {
    my $sc = shift; # scale
    croak "ERROR: undefined sc" unless defined $sc;
    return '*' x $sc . '.' x ($bar_max - $sc);
}

# add grid to bar
sub grid_bar {
    my $bar = shift; # bar characters
    my $sc = shift;  # scale

    croak "ERROR: undefined bar" unless defined $bar;
    croak "ERROR: undefined sc" unless defined $sc;
    my $b = length($bar);
    croak "ERROR: initial bar=$b" if $b != $bar_max;

    for (my $pc = 10; $pc < 100; $pc += 10) {
        my $pcs = scale_pc($pc, $sc);

        my $mi = $pcs > 0 ? $pcs - 1 : $pcs;

        my $left = substr($bar, 0, $mi);
        my $middle = substr($bar, $mi, 1);
        my $right = substr($bar, $mi + 1);

        $middle =~ tr/*./#|/;
        $bar = $left . $middle . $right;

        my ($l, $m, $r, $b) = (length($left), length($middle), length($right), length($bar));
        croak "ERROR: pc=$pc, sc=$sc, pcs=$pcs, mi=$mi, left=$l, middle=$m, right=$r, bar=$b" if length($bar) != $bar_max;
    }
    return $bar;
}

