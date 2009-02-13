use strict;
use warnings;
use Time::HiRes qw( time );
use lib qw(
Parse-HTTP-UserAgent\lib
lib
);
use Parse::HTTP::UserAgent -dumper, -extended;

#my $ua =
my @ua;

@ua = grep {$_} (split(/\n/,q{
Mozilla/5.0 (Windows NT 6.0; U; en; rv:1.8.1) Gecko/20061208 Firefox/2.0.0 Opera 9.51
}));

do { my $o = Parse::HTTP::UserAgent->new($_); $o->dumper( type => 'dumper', format => 'pretty' ) } for @ua;

my $u = Parse::HTTP::UserAgent->new(pop@ua);

print "ZUB: $u\n";
printf "S: %s\n", $u;
printf "D: %f\n", $u;
print "VER: " . ($u + 1) . "\n";
print $u > 5 ? "oye komova\n" : "que pasa?\n";
#print $ua->is('firefox') ? "FF!" : "N/A";

__END__















my %ua = map { [] } qw( ie4 ie5 ie55 ie6 ie7 ff3 ff2 mozilla safari opera );

push @{ $ua{ie7} }, q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022; InfoPath.2)};
push @{ $ua{ff3} }, q{Mozilla/5.0 (Windows; U; Windows NT 5.1; tr; rv:1.9.0.3) Gecko/2008092417 Firefox/3.0.3}
push @{ $ua{opera} }, q{Opera/9.62 (Windows NT 5.1; U; tr) Presto/2.1.1};

$ua->is('firefox') && $ua->version >= 3
$ua->tk('presto') && $ua->version >= 2.001001


5.8.8
5.008008
