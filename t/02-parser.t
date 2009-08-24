#!/usr/bin/env perl -w
use strict;
use vars qw( $VERSION );
use Test::More qw( no_plan );
use File::Spec;
use Data::Dumper;
use Parse::HTTP::UserAgent -all;

require_ok( File::Spec->catfile( t => 'db.pl' ) );

my %seen;
foreach my $test ( database({ thaw => 1 }) ) {
    die "No user-agent string defined?"     if ! $test->{string};
    die "Already tested '$test->{string}'!" if   $seen{ $test->{string} }++;
    my $parsed = Parse::HTTP::UserAgent->new( $test->{string} );
    my %got    = $parsed->as_hash;

    if ( ! $test->{struct} ) {
       die "No data in the test result set? Expected something matches "
          ."with these:\n$test->{string}\n\n"
          . do { delete $got{string}; Dumper(\%got) };
    }

    is( delete $got{string}, $test->{string}, "Ok got the string back for $got{name}" );
    # remove undefs, so that we can extend the test data with less headache
    %got = map { $_ => $got{ $_ } } grep { defined $got{$_} } keys %got;
    is_deeply( \%got, $test->{struct},
               "Frozen data matches parse result for '$test->{string}' -> $got{parser}" );
}


__END__
