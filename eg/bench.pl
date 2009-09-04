use strict;
use warnings;
use Getopt::Long;

GetOptions(\my %opt, qw(
    count=i
));

use HTTP::BrowserDetect;
use Parse::HTTP::UserAgent;
use HTTP::DetectUserAgent;
use HTML::ParseBrowser;
use Benchmark qw( :all :hireswallclock );
use lib       qw( .. );

our $SILENT = 1;

my $HPB = my $ua = HTML::ParseBrowser->new;

sub html_parsebrowser     { my $ua = HTML::ParseBrowser->new(     shift ); $ua; }
sub html_parsebrowser2    { my $ua = $HPB->Parse(shift); $ua; }
sub http_browserdetect    { my $ua = HTTP::BrowserDetect->new(    shift ); $ua; }
sub http_detectuseragent  { my $ua = HTTP::DetectUserAgent->new(  shift ); $ua; }
sub parse_http_useragent  { my $ua = Parse::HTTP::UserAgent->new( shift ); $ua; }
sub parse_http_useragent2 { my $ua = Parse::HTTP::UserAgent->new( shift, {extended=>0} ); $ua; }

require 't/db.pl';

my $count = $opt{count} || 100;
my @tests = map { $_->{string} } database({ thaw => 1 });
my $total = @tests;

print <<"ATTENTION";
*** The data integrity is not checked in this run.
*** This is a benchmark for parser speeds.
*** Testing $total User Agent strings on each module with $count iterations each.

This may take a while. Please stand by ...

ATTENTION

my $start = Benchmark->new;

cmpthese( $count, {
    HTML    => sub { foreach my $s (@tests) { my $ua = html_parsebrowser(     $s ) } },
    HTML2   => sub { foreach my $s (@tests) { my $ua = html_parsebrowser2(    $s ) } },
    Browser => sub { foreach my $s (@tests) { my $ua = http_browserdetect(    $s ) } },
    Detect  => sub { foreach my $s (@tests) { my $ua = http_detectuseragent(  $s ) } },
    Parse   => sub { foreach my $s (@tests) { my $ua = parse_http_useragent(  $s ) } },
    Parse2  => sub { foreach my $s (@tests) { my $ua = parse_http_useragent2( $s ) } },
});

my $runtime = timestr( timediff(Benchmark->new, $start) );

print <<"GOODBYE";

The code took: $runtime 

---------------------------------------------------------

List of abbreviations:

HTML      HTML::ParseBrowser v$HTML::ParseBrowser::VERSION
HTML2     HTML::ParseBrowser v$HTML::ParseBrowser::VERSION (re-use the object)
Browser   HTTP::BrowserDetect v$HTTP::BrowserDetect::VERSION
Detect    HTTP::DetectUserAgent v$HTTP::DetectUserAgent::VERSION
Parse     Parse::HTTP::UserAgent v$Parse::HTTP::UserAgent::VERSION
Parse2    Parse::HTTP::UserAgent v$Parse::HTTP::UserAgent::VERSION (without extended probe)
GOODBYE

__END__
