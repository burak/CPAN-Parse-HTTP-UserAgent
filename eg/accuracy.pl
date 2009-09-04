use strict;
use warnings;
use Getopt::Long;

GetOptions(\my %opt, qw(
    debug
));

use HTTP::BrowserDetect;
use Parse::HTTP::UserAgent;
use HTTP::DetectUserAgent;
use HTML::ParseBrowser;
use Data::Dumper;
use Text::Table;
use lib qw( .. );

our $SILENT = 1;

require 't/db.pl';

my @tests = database({ thaw => 1 });
my $total = @tests;

print <<"ATTENTION";
*** This is a test to compare the accuracy of the parsers.
*** The data set is from the test suite. There are $total UA strings
*** Parse::HTTP::UserAgent will detect all of them
*** A tiny fraction of the regressions can be related to wrong parsing.
*** Equation tests are not performed. Tests are boolean.

This may take a while. Please stand by ...

ATTENTION

my %fail = (
    'Parse::HTTP::UserAgent' => { name => {}, version => 0, os => 0, lang => 0 },
    'HTML::ParseBrowser'     => { name => {}, version => 0, os => 0, lang => 0 },
    'HTTP::DetectUserAgent'  => { name => {}, version => 0, os => 0, lang => 0 },
    'HTTP::BrowserDetect'    => { name => {}, version => 0, os => 0, lang => 0 },
);

my %total;
foreach my $test ( @tests ) {
    my %ok   = parse_http_useragent( $test->{string} );
    my %hdua = http_detectuseragent( $test->{string} );
    my %hpb  = html_parsebrowser(    $test->{string} );
    my %hbd  = http_browserdetect(   $test->{string} );

    my $is_name    = $ok{name}    || $hpb{name} || $hbd{name}    || $hdua{name};
    my $is_lang    = $ok{lang}    || $hpb{lang} || $hbd{lang}    || $hdua{lang};
    my $is_version = $ok{version} || $hpb{v}    || $hbd{version} || $hdua{version};
    my $is_os      = $ok{os}      || $hpb{os}   || $hbd{os}      || $hdua{os};

    ++$total{name}    if $is_name;
    ++$total{lang}    if $is_lang;
    ++$total{version} if $is_version;
    ++$total{os}      if $is_os;

    $hdua{name} = '' if $hdua{name} && $hdua{name} eq 'Unknown';

      $fail{'Parse::HTTP::UserAgent'}->{lang            }++ if $is_lang    && ! $ok{lang};
      $fail{'HTTP::DetectUserAgent' }->{lang            }++ if $is_lang    && ! $hdua{lang};
      $fail{'HTML::ParseBrowser'    }->{lang            }++ if $is_lang    && ! $hpb{lang};
      $fail{'HTTP::BrowserDetect'   }->{lang            }++ if $is_lang    && ! $hbd{lang};

      $fail{'Parse::HTTP::UserAgent'}->{version         }++ if $is_version && ! $ok{version};
      $fail{'HTTP::DetectUserAgent' }->{version         }++ if $is_version && ! $hdua{version};
      $fail{'HTML::ParseBrowser'    }->{version         }++ if $is_version && ! $hpb{v};
      $fail{'HTTP::BrowserDetect'   }->{version         }++ if $is_version && ! $hbd{version};

      $fail{'Parse::HTTP::UserAgent'}->{os              }++ if $is_os      && ! $ok{os};
      $fail{'HTTP::DetectUserAgent' }->{os              }++ if $is_os      && ! $hdua{os};
      $fail{'HTML::ParseBrowser'    }->{os              }++ if $is_os      && ! $hpb{os};
      $fail{'HTTP::BrowserDetect'   }->{os              }++ if $is_os      && ! $hbd{os};

    ++$fail{'Parse::HTTP::UserAgent'}->{name}{ $is_name }   if $is_name    && ! $ok{name};
    ++$fail{'HTTP::DetectUserAgent' }->{name}{ $is_name }   if $is_name    && ! $hdua{name};
    ++$fail{'HTML::ParseBrowser'    }->{name}{ $is_name }   if $is_name    && ! $hpb{name};
    ++$fail{'HTTP::BrowserDetect'   }->{name}{ $is_name }   if $is_name    && ! $hbd{name};

    my $phua_fail = ( $is_lang    && ! $ok{lang}    ) ||
                    ( $is_version && ! $ok{version} ) ||
                    ( $is_os      && ! $ok{os}      ) ||
                    ( $is_name    && ! $ok{name}    );

#print <<"FOO";
#$ok{name} $ok{version} $ok{os}
#$hpb{name} $hpb{v} $hpb{os}
#$hdua{name} $hdua{version} $hdua{os}
#
#FOO

    if ( $opt{debug} && $phua_fail ) {
        print "$test->{string}\n";
        print "LANG   : $is_lang\n"    if $is_lang    && ! $ok{lang};
        print "VERSION: $is_version\n" if $is_version && ! $ok{version};
        print "OS     : $is_os\n"      if $is_os      && ! $ok{os};
        print "NAME   : $is_name\n"    if $is_name    && ! $ok{name};
        print Dumper({
            parse_http_useragent => \%ok,
            http_detectuseragent => \%hdua,
            html_parsebrowser    => \%hpb,
            http_browserdetect   => \%hbd,
        });
        print "-" x 80, "\n";
    }
}

my $tb = Text::Table->new(
    '|', "Parser",
    '|', "Name FAILS",
    '|', "Version FAILS",
    '|', "Language FAILS",
    '|', "OS FAILS",
    '|',
);

foreach my $parser ( keys %fail ) {
    my $all = $fail{$parser}->{name};
    my $name = 0;
    $name += $all->{$_} for keys %{ $all };
    my $v  = ratio( $fail{$parser}->{version}, $total{version} );
    my $l  = ratio( $fail{$parser}->{lang}   , $total{lang}    );
    my $os = ratio( $fail{$parser}->{os}     , $total{os}      );
    $name  = ratio( $name                    , $total{name}    );

    $tb->load([
        '|', $parser,
        '|', $name,
        '|', $v,
        '|', $l,
        '|', $os,
        '|',
    ]);
}

print $tb->rule( '-', '+')
    . $tb->title
    . $tb->rule( '-', '+')
    . $tb->body
    . $tb->rule( '-', '+')
;

sub ratio {
    my $v   = shift;
    my $tot = shift;
    my $r   = $v ? sprintf('%.2f', ($v*100)/$tot) : '0.00';
    return sprintf "% 4d - % 6s%%", $v, $r;
}

sub parse_http_useragent {
    my $ua    = Parse::HTTP::UserAgent->new( shift );
    my %rv    = $ua->as_hash;
    $rv{name} = 'Internet Explorer' if $rv{name} && $rv{name} eq 'MSIE';
    return %rv;
}

sub html_parsebrowser {
    my $ua = HTML::ParseBrowser->new( shift );
    # !!! version() returns a hash. you'll want v()
    my %rv = map { $_ => $ua->$_() } qw(
        user_agent
        languages
        language
        langs
        lang
        detail
        useragents
        properties
        name
        version
        v
        major
        minor
        os
        ostype
        osvers
        osarc
    );
    return %rv;
}

sub http_browserdetect {
    # can not detect lang
    my $ua = HTTP::BrowserDetect->new( shift );
    return version => $ua->version,
           os      => $ua->os_string,
           name    => $ua->browser_string,
           ;
}

sub http_detectuseragent  {
    my $ua = HTTP::DetectUserAgent->new(  shift );
    my %rv = map { $_ => $ua->$_() } qw (name version vendor type os);
    return %rv;
}
