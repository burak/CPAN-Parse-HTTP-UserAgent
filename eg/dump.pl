#!/usr/bin/env perl -w
# (c) 2009 Burak Gursoy. Distributed under the Perl License.
# Enables internal pre-parsed structure dumper and then dumps
#    the parsed structure.
use strict;
use warnings;
use lib qw( ../lib lib );

our $VERSION = '0.10';

BEGIN {
    sub Parse::HTTP::UserAgent::DEBUG { 1 }
}

use Parse::HTTP::UserAgent -all;

print Parse::HTTP::UserAgent->new( shift || die "UserAgent?" )->dumper;
