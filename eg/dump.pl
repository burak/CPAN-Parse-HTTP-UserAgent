#!/usr/bin/env perl -w
# (c) 2009 Burak Gursoy. Distributed under the Perl License.
# Enables internal pre-parsed structure dumper and then dumps
#    the parsed structure.
use strict;
use warnings;
use lib qw( ../lib lib );

our $VERSION = '0.10';

BEGIN {
    *Parse::HTTP::UserAgent::DEBUG = sub () { 1 }
}

use Parse::HTTP::UserAgent -all;

my $pok = print Parse::HTTP::UserAgent->new( shift || die "UserAgent?\n" )->dumper;
