#!/usr/bin/env perl
use strict;
use warnings;
use Wx;
use Data::Dumper;
use IO::Socket;
use JSON::Parse 'json_to_perl';

my $sock = new IO::Socket::INET (
                                 PeerAddr => 'localhost',
                                 PeerPort => '2947',
                                 Proto => 'tcp',
    Blocking => 0
                                );
die "Could not create socket: $!\n" unless $sock;
while(<$sock>)
{
    print Dumper(json_to_perl $_);
}
print("?WATCH;\n");
    $sock->print("?WATCH={\"enable\":true};\n");
    while(<$sock>)
    {
	print Dumper(json_to_perl $_);
    }
while(1)
{
    sleep(1);
    print("?POLL;\n");
    $sock->print("?POLL;\n");
    while(<$sock>)
    {
	print Dumper(json_to_perl $_);
    }
}
close($sock);
