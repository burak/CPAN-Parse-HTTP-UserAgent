use strict;
use warnings;

my $count = 100;

use HTTP::BrowserDetect;
use Parse::HTTP::UserAgent;
use HTTP::DetectUserAgent;
use HTML::ParseBrowser;
use Benchmark qw( :all :hireswallclock );
use lib qw( .. );

our $SILENT = 1;

require 't/db.pl';

my @tests = map { $_->{string} } database({ thaw => 1 });

printf "*** The data integrity is not checked in this run.\n";
printf "*** This is a benchmark for parser speeds.\n";
printf "*** Testing %d User Agent strings on each module with $count iterations.\n\n", scalar @tests;

print "This may take a while. Please stand by ...\n\n";

my $start = Benchmark->new;

cmpthese( $count, {
    'HTML::ParseBrowser'     => sub { foreach my $s (@tests) { my $ua = html_parsebrowser($s)    } },
    'HTTP::BrowserDetect'    => sub { foreach my $s (@tests) { my $ua = http_browserdetect($s)   } },
    'HTTP::DetectUserAgent'  => sub { foreach my $s (@tests) { my $ua = http_detectuseragent($s) } },
    'Parse::HTTP::UserAgent' => sub { foreach my $s (@tests) { my $ua = parse_http_useragent($s) } },
});

printf "\nThe code took: %s\n", timestr( timediff(Benchmark->new, $start) );

sub html_parsebrowser    { my $ua = HTML::ParseBrowser->new(     shift ); $ua; }
sub http_browserdetect   { my $ua = HTTP::BrowserDetect->new(    shift ); $ua; }
sub http_detectuseragent { my $ua = HTTP::DetectUserAgent->new(  shift ); $ua; }
sub parse_http_useragent { my $ua = Parse::HTTP::UserAgent->new( shift ); $ua; }
