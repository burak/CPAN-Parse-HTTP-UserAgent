#!/usr/bin/env perl -w
use strict;
use vars qw( $VERSION );
use Test::More qw( no_plan );
use File::Spec;
use IO::File;
use Getopt::Long;
use constant DATABASE => File::Spec->catfile(qw( t data ua.txt ));

$VERSION = '0.10';

GetOptions(\my %opt, qw(
    dump
    debug
));

use Parse::HTTP::UserAgent -all;

my(%test);
init();

my(@todo,@wrong);

foreach my $id ( sort keys %test ) {
    foreach my $str ( @{ $test{ $id } } ) {
        SKIP: {
            my $ua = Parse::HTTP::UserAgent->new( $str );
            ok( defined $ua, "We got an object");
            my $oops;

            if ( $ua->unknown ) {
                if ( $id eq 'various' ) {
                    push @todo, $str;
                    skip("Skipping unknown string: $str");
                }
                else {
                    $oops = 1;
                }
            }

            if ( ! $ua->robot && ! $ua->generic && ( $oops || $ua->name !~ m{ \b $id \b}xmsi ) ) {
                my $e = sprintf qq{%s instead of %s\t'%s'},
                                $oops ? 'unknown' : lc $ua->name,
                                lc $id,
                                $str;
                push @wrong, $e;
                fail("Bogus parse result! $e");
            }

            ok(1, "Found a robot: $str") if $ua->robot;

            # interface
            ok( $ua->name, "It has name" );
            ok( defined $ua->version, "It has version - $str" );
            ok( defined $ua->version('raw'), "It has raw version" );
            if ( $id eq 'msie' ) {
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

sub init {
    my $FH = IO::File->new;
    $FH->open( DATABASE, 'r')
        or die sprintf("Can not open DB @ %s: %s", DATABASE, $!);
    my $id;
    while ( my $line = readline $FH ) {
        chomp $line;
        next if ! $line || $line =~ m{ \A \# }xms; # ignore comments and empty lines
        if ( $line =~ m{ \A \[ ([a-zA-Z0-9_]+?) \] \z }xms ) {
            $id = $1;
            $test{$id} = [];
            next;
        }
        die "No id?!?!?!?!?!????" if not $id;
        push @{ $test{$id} }, $line;
    }
    $FH->close;
}

__END__

