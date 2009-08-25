#!/usr/bin/env perl -w
use strict;
use vars qw( $VERSION $SILENT );
use Test::More qw( no_plan );
use File::Spec;
use Getopt::Long;
use Parse::HTTP::UserAgent;

require_ok( File::Spec->catfile( t => 'db.pl' ) );

GetOptions(\my %opt, qw(
    dump
    debug
    supported
));

$SILENT = 1;

my(@todo,@wrong, %supported);
RUN: {
    foreach my $test ( database() ) {
        my $str = $test->{string};
        SKIP: {
            my $ua = Parse::HTTP::UserAgent->new( $str );
            ok( defined $ua, "We got an object");
            my $oops;
            $oops = 1 if $ua->unknown;

            if ( ! $ua->robot && ! $ua->generic && $oops ) {
                my $e = sprintf qq{%s instead of %s\t'%s'},
                                $oops ? 'unknown' : lc $ua->name,
                                '???',
                                $str;
                push @wrong, $e;
                fail("Bogus parse result! $e");
            }

            ok(1, "Found a robot: $str") if $ua->robot;

            # interface
            ok( $ua->name, "It has name" );
            ok( defined $ua->version       , "It has version - $str" );
            ok( defined $ua->version('raw'), "It has raw version" );
            if ( $ua->name eq 'MSIE' ) {
                my @net = $ua->dotnet;
                @net ? ok( scalar @net, "We got .NET CLR: @net")
                     : $opt{debug} && diag("No .NET identifier in the MSIE Agent: $str");
            }

            $ua->os   ? ok(1, sprintf("The Operating System is '%s'", $ua->os) )
                      : $opt{debug} && diag("No operating system from $str");
            $ua->lang ? ok(1, sprintf("The Interface Language is '%s'", $ua->lang) )
                      : $opt{debug} && diag("No language identifier from $str");

            my @mozilla = $ua->mozilla;
            my @toolkit = $ua->toolkit;
            my @extras  = $ua->extras;

            if ( $opt{debug} ) {
                diag "Extras are: @extras" if @extras;
                diag "Toolkit: @toolkit"   if @toolkit;
                diag "Mozilla: @mozilla"   if @mozilla;
            }

            # dump the parsed structure
            ok( my $dump = $ua->dumper, "It can dump");
            diag $dump if $opt{dump};
            $supported{ $ua->original_name || $ua->name }++ if $opt{supported};
        }
    }
}

if ( @todo ) {
    diag "-" x 80;
    diag "UserAgents not yet recognized:";
    diag $_ for @todo;
}

if ( @wrong ) {
    diag "-" x 80;
    diag "BOGUS parse results:";
    diag $_ for @wrong;
}

if ( $opt{supported} ) {
    diag "Supported user agents are:";
    foreach my $name ( sort { lc $a cmp lc $b } keys %supported ) {
        diag "\t$name";
    }
}
