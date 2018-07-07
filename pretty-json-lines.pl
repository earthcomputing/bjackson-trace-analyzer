#!/usr/bin/perl -w

my $exec = 'python -mjson.tool';
while (<>) {
    open(FD, '|'.$exec) or die $exec.': '.$!;
    print FD ($_);
    close(FD);
}

