#!/usr/bin/env perl -w
use strict;
use warnings;
use vars qw( $VERSION $SILENT );
use Test::More qw( no_plan );
use File::Spec;
use Data::Dumper;
use Getopt::Long;
use Parse::HTTP::UserAgent;
use Carp qw( croak );

GetOptions(\my %opt, qw(
    ids=i@
    dump
));

require_ok( File::Spec->catfile( t => 'db.pl' ) );

my %wanted = $opt{ids} ? map { ( $_, $_ ) } @{ $opt{ids} } : ();

sub ok_to_test {
    my $id = shift;
    return 1 if ! %wanted;
    return $wanted{ $id };
}

my %seen;
foreach my $test ( database({ thaw => 1 }) ) {
    next if ! ok_to_test( $test->{id} );
    die "No user-agent string defined?\n"     if ! $test->{string};
    die "Already tested '$test->{string}'!\n" if   $seen{ $test->{string} }++;
    my $parsed = Parse::HTTP::UserAgent->new( $test->{string} );
    my %got    = $parsed->as_hash;

    if ( ! $test->{struct} ) {
        fail 'No data in the test result set? Expected something matching '
            . "with these:\n$test->{string}\n\n"
            . do { delete $got{string}; Dumper(\%got) };
        next;
    }

    is( delete $got{string}, $test->{string}, "Ok got the string back for $got{name}" );
    # remove undefs, so that we can extend the test data with less headache
    %got = map { $_ => $got{ $_ } } grep { defined $got{$_} } keys %got;
    is_deeply( \%got, $test->{struct},
               "Frozen data matches parse result for '$test->{string}' -> $got{parser} -> $test->{id}" );
    if ( $opt{dump} ) {
        diag 'GOT:'.Dumper(\%got) . "\nEXPECTED:". Dumper($test->{struct});
    }
}


__END__
