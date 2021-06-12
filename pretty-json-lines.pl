#!/usr/local/bin/perl -w
#!/usr/bin/perl -w
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

my $exec = 'python -mjson.tool';
while (<>) {
    open(FD, '|'.$exec) or die $exec.': '.$!;
    print FD ($_);
    close(FD);
}

