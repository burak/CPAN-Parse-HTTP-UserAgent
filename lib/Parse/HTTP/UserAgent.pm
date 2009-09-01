package Parse::HTTP::UserAgent;
use strict;
use vars qw( $VERSION );

$VERSION = '0.15';

use base qw(
    Parse::HTTP::UserAgent::Base::IS
    Parse::HTTP::UserAgent::Base::Parsers
    Parse::HTTP::UserAgent::Base::Dumper
    Parse::HTTP::UserAgent::Base::Accessors
);
use overload '""',    => 'name',
             '0+',    => 'version',
             fallback => 1,
;
use constant RE_WARN_OVERFLOW => qr{Integer overflow in version};
use constant RE_WARN_INVALID  => qr{Version string .+? contains invalid data; ignoring:};
use version;
use Parse::HTTP::UserAgent::Constants qw(:all);
use Carp qw( croak );

BEGIN {
    constant->import( DEBUG => 0 ) if not defined &DEBUG;
}

my %OSFIX = (
    'WinNT4.0'       => 'Windows NT 4.0',
    'WinNT'          => 'Windows NT',
    'Windows 4.0'    => 'Windows 95',
    'Win95'          => 'Windows 95',
    'Win98'          => 'Windows 98',
    'Windows 4.10'   => 'Windows 98',
    'Win 9x 4.90'    => 'Windows Me',
    'Windows NT 5.0' => 'Windows 2000',
    'Windows NT 5.1' => 'Windows XP',
    'Windows NT 5.2' => 'Windows Server 2003',
    'Windows NT 6.0' => 'Windows Vista / Server 2008',
    'Windows NT 6.1' => 'Windows 7',
);

sub new {
    my $class = shift;
    my $ua    = shift || croak "No user agent string specified";
    my $opt   = shift || {};
    croak "Options must be a hash reference" if ref $opt ne 'HASH';
    my $self  = [ map { undef } 0..MAXID ];
    bless $self, $class;
    $self->[UA_STRING]   = $ua;
    $self->[IS_EXTENDED] = exists $opt->{extended} ? $opt->{extended} : 1;
    $self->_parse;
    return $self;
}

sub as_hash {
    my $self   = shift;
    my @ids    = $self->_object_ids;
    my %struct = map {
                    my $id = $_;
                    $id =~ s{ \A UA_ }{}xms;
                    lc $id, $self->[ $self->$_() ]
                 } @ids;
    return %struct;
}

sub trim {
    my $self = shift;
    my $s    = shift;
    return $s if ! $s;
    $s =~ s{ \A \s+    }{}xms;
    $s =~ s{    \s+ \z }{}xms;
    return $s;
}

sub _parse {
    my $self = shift;
    return $self if $self->[IS_PARSED];
    $self->_do_parse( $self->_pre_parse );
    $self->[IS_PARSED] = 1;
    $self->_post_parse if ! $self->[UA_UNKNOWN];
    return;
}

sub _pre_parse {
    my $self = shift;
    $self->[IS_MAXTHON] = index(uc $self->[UA_STRING], 'MAXTHON') != -1;
    my $ua = $self->[UA_STRING];
    my($moz, $thing, $extra, @others) = split RE_SPLIT_PARSE, $ua;
    $thing = $thing ? [ split RE_SC_WS, $thing ] : [];
    $extra = [ split RE_WHITESPACE, $extra ] if $extra;
    $self->_debug_pre_parse( $moz, $thing, $extra, @others ) if DEBUG;
    return $moz, $thing, $extra, @others;
}

sub _do_parse {
    my $self = shift;
    my($m, $t, $e, @o) = @_;
    my $c = $t->[0] && $t->[0] eq 'compatible';

    if ( $c && shift @{$t} && ! $e && ! $self->[IS_MAXTHON] ) {
        my($n, $v) = split RE_WHITESPACE, $t->[0];
        if ( $n eq 'MSIE' && index($m, ' ') == -1 ) {
            $self->[UA_PARSER] = 'msie';
            return $self->_parse_msie($m, $t, $e, $n, $v);
        }
    }

    my $rv =  $self->_is_opera_pre($m)   ? [opera_pre  => $m, $t, $e           ]
            : $self->_is_opera_post($e)  ? [opera_post => $m, $t, $e, $c       ]
            : $self->_is_opera_ff($e)    ? [opera_pre  => "$e->[2]/$e->[3]", $t]
            : $self->_is_ff($e)          ? [firefox    => $m, $t, $e, @o       ]
            : $self->_is_safari($e, \@o) ? [safari     => $m, $t, $e, @o       ]
            : $self->_is_chrome($e, \@o) ? [chrome     => $m, $t, $e, @o       ]
            : $self->[IS_MAXTHON]        ? [maxthon    => $m, $t, $e, @o       ]
            : undef;

    if ( $rv ) {
        my $pname  = shift( @{ $rv } );
        my $method = '_parse_' . $pname;
        $self->[UA_PARSER] = $pname;
        return $self->$method( @{ $rv } );
    }

    return $self->_extended_probe($m, $t, $e, $c, @o) if $self->[IS_EXTENDED];

    $self->[UA_UNKNOWN] = 1; # give up
    return;
}

sub _post_parse {
    my $self = shift;
    $self->[UA_VERSION] = $self->_numify( $self->[UA_VERSION_RAW] )
        if $self->[UA_VERSION_RAW];

    my @buf;
    foreach my $e ( @{ $self->[UA_EXTRAS] } ) {
        if ( $self->_is_strength( $e ) ) {
            $self->[UA_STRENGTH] = $e ;
            next;
        }
        push @buf, $e;
    }

    $self->[UA_EXTRAS] = [ @buf ];

    if ( $self->[UA_TOOLKIT] ) {
        push @{ $self->[UA_TOOLKIT] }, $self->_numify( $self->[UA_TOOLKIT][1] );
    }

    if( $self->[UA_MOZILLA] ) {
        $self->[UA_MOZILLA] =~ tr/a-z://d;
        $self->[UA_MOZILLA] = [ $self->[UA_MOZILLA],
                                $self->_numify( $self->[UA_MOZILLA] ) ];
    }

    if ( $self->[UA_OS] ) {
        $self->[UA_OS] = $OSFIX{ $self->[UA_OS] } || $self->[UA_OS];
    }

    foreach my $robo ( LIST_ROBOTS ) { # regex???
        next if lc $robo ne lc $self->[UA_NAME];
        $self->[UA_ROBOT] = 1;
        last;
    }
    return;
}

sub _extended_probe {
    my $self = shift;

    return if $self->_is_gecko          && $self->_parse_gecko(    @_ );
    return if $self->_is_netscape( @_ ) && $self->_parse_netscape( @_ );
    return if $self->_is_docomo(   @_ ) && $self->_parse_docomo(   @_ );
    return if $self->_is_generic(  @_ );

    $self->[UA_UNKNOWN] = 1;
    return;
}

sub _object_ids {
    return grep { $_ =~ RE_OBJECT_ID } keys %Parse::HTTP::UserAgent::;
}

sub _numify {
    my $self = shift;
    my $v    = shift || return 0;
    $v    =~ s{
                pre      |
                \-stable |
                gold     |
                [ab]\d+  |
                \+
                }{}xmsig;
    # Gecko revisions like: "20080915000512" will cause an
    #   integer overflow warning. use bigint?
    local $SIG{__WARN__} = sub {
        warn $_[0] if $_[0] !~ RE_WARN_OVERFLOW && $_[0] !~ RE_WARN_INVALID;
    };
    # if version::vpp is used it'll identify 420 as a v-string
    # add a floating point to fool it
    $v .= '.0' if index($v, '.') == -1;
    my $rv = version->new("$v")->numify;
    return $rv;
}

sub _debug_pre_parse {
    my $self = shift;
    my($moz, $thing, $extra, @others) = @_;

    my $raw = [
                { qw/ name moz    value / => $moz     },
                { qw/ name thing  value / => $thing   },
                { qw/ name extra  value / => $extra   },
                { qw/ name others value / => \@others },
            ];
    print "-------------- PRE PARSE DUMP --------------\n"
        . $self->dumper(args => $raw)
        . "--------------------------------------------\n";
    return;
}

1;

__END__

=pod

=head1 NAME

Parse::HTTP::UserAgent - Parser for the User Agent string

=head1 SYNOPSIS

   use Parse::HTTP::UserAgent;
   my $ua = Parse::HTTP::UserAgent->new( $str );
   die "Unable to parse!" if $ua->unknown;
   print $ua->name;
   print $ua->version;
   print $ua->os;
   # or just dump for debugging:
   print $ua->dumper;

=head1 DESCRIPTION

Quoting L<http://www.webaim.org/blog/user-agent-string-history/>:

   " ... and then Google built Chrome, and Chrome used Webkit, and it was like
   Safari, and wanted pages built for Safari, and so pretended to be Safari.
   And thus Chrome used WebKit, and pretended to be Safari, and WebKit pretended
   to be KHTML, and KHTML pretended to be Gecko, and all browsers pretended to
   be Mozilla, (...) , and the user agent string was a complete mess, and near
   useless, and everyone pretended to be everyone else, and confusion
   abounded."

User agent strings are a complete mess since there is no standard format for
them. They can be in various formats and can include more or less information
depending on the vendor's (or the user's) choice. Also, it is not dependable
since it is some arbitrary identification string. Any user agent can fake
another. So, why deal with such a useless mess? You may want to see the choice
of your visitors and can get some reliable data (even if some are fake) and
generate some nice charts out of them or just want to send a C<HttpOnly> cookie
if the user agent seem to support it (and send a normal one if this is not the
case). However, browser sniffing for client-side coding is considered a bad
habit.

This module implements a rules-based parser and tries to identify
MSIE, FireFox, Opera, Safari & Chrome first. It then tries to identify Mozilla,
Netscape, Robots and the rest will be tried with a generic parser. There is
also a structure dumper, useful for debugging.

=head1 METHODS

=head2 new STRING [, OPTIONS ]

Constructor. Takes the user agent string as the only parameter and returns
an object based on the parsed structure.

The optional C<OPTIONS> parameter (must be a hashref) can be used to pass
several parameters:

=over 4

=item *

C<extended>: controls if the extended probe qill be used or not. Default
is true. Set this to false to disable:

   $ua = Parse::HTTP::UserAgent->new( $str, { extended => 0 } );

Can be used to speed up the parser by disabling detection of non-major browsers.

=back

=head2 trim STRING

Trims the string.

=head2 as_hash

Returns a hash representation of the parsed structure.

=head2 dumper

See L<Parse::HTTP::UserAgent::Base::Dumper>.

=head2 accessors

See L<Parse::HTTP::UserAgent::Base::Accessors> for the available accessors you can
use on the parsed object.

=head1 OVERLOADED INTERFACE

The object returned, overloads stringification (C<name>) and numification
(C<version>) operators. So that you can write this:

    print 42 if $ua eq 'Opera' && $ua >= 9;

instead of this

    print 42 if $ua->name eq 'Opera' && $ua->version >= 9;

=head1 ERROR HANDLING

=over 4

=item *

If you pass a false value to the constructor, it'll croak.

=item *

If you pass a non-hashref option to the constructor, it'll croak.

=item *

If you pass a wrong parameter to the dumper, it'll croak.

=back

=head1 SEE ALSO

=head2 Similar Functionality

=over 4

=item *

L<HTTP::BrowserDetect>

=item *

L<HTML::ParseBrowser>

=item *

L<HTTP::DetectUserAgent>

=item *

L<HTTP::MobileAgent>

=back

=head2 Resources

=over 4

=item *

L<http://en.wikipedia.org/wiki/User_agent>,

=item *

L<http://www.zytrax.com/tech/web/browser_ids.htm>,

=item *

L<http://www.zytrax.com/tech/web/mobile_ids.html>,

=item *

L<http://www.webaim.org/blog/user-agent-string-history/>.

=back

=cut
