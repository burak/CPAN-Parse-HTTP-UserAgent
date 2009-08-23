#!/usr/bin/env perl -w
use strict;
use vars qw( $VERSION );
use Test::More qw( no_plan );
use File::Spec;
use IO::File;
use Getopt::Long;
use Data::Dumper;
use constant DATABASE  => File::Spec->catfile(qw( t data parse.dat ));
use constant RE_SEPTOR => qr{ \Q[AGENT]\E }xms;
$VERSION = '0.10';

GetOptions(\my %opt, qw(
    dump
    debug
));

use Parse::HTTP::UserAgent -all;

my $tests = trim( slurp() );

foreach my $test ( split RE_SEPTOR, $tests ) {
    next if ! $test;
    my $raw = trim( strip_comments( $test ) ) || next;
    my($string, $frozen) = split m{ \n }xms, $raw, 2;
    die "No string?" if ! $string;
    my $parsed = Parse::HTTP::UserAgent->new( $string );
    my %got    = $parsed->as_hash;
    if ( ! $frozen ) {
       die "No data in the test result set? Expected something matches with these:\n$string\n\n"
           . do { delete $got{string}; Dumper(\%got) };
    }
    my %expected = thaw( $frozen );
    is( delete $got{string}, $string, 'Ok got the string back for ' . $got{name} );
    # remove undefs, so that we can extend the test data with less headache
    %got = map { $_ => $got{ $_ } } grep { defined $got{$_} } keys %got;
    is_deeply( \%got, \%expected, 'Frozen data matches parse result for ' . $got{name} );
}

sub thaw {
    my $s = shift || die "Frozen?";
    my %rv;
    eval "\%rv = (\n $s \n);";
    die "Can not restore data: $@" if $@;
    return %rv;
}

sub trim {
    my $s = shift;
    return $s if ! $s;
    $s =~ s{ \A \s+    }{}xms;
    $s =~ s{    \s+ \z }{}xms;
    return $s;
}

sub strip_comments {
    my $s = shift;
    return $s if ! $s;
    my $buf = '';
    foreach my $line ( split m{ \n }xms, $s ) {
        chomp $line;
        next if ! $line;
        next if $line =~ m{ \A [#] }xms;
        $buf .= $line . "\n";
    }
    return $buf;
}

sub slurp {
    my $FH = IO::File->new;
    $FH->open( DATABASE, 'r')
        or die sprintf("Can not open DB @ %s: %s", DATABASE, $!);
    my $rv = do { local $/; my $s = <$FH>; $s };
    $FH->close;
    return $rv;
}

__END__
