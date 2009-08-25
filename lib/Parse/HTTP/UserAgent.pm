package Parse::HTTP::UserAgent;
use strict;
use vars qw( $VERSION );

$VERSION = '0.10';

use base qw(
    Parse::HTTP::UserAgent::IS
    Parse::HTTP::UserAgent::Parsers
    Parse::HTTP::UserAgent::Dumper
);
use overload '""',    => 'name',
             '0+',    => 'version',
             fallback => 1,
;
use version;
use Parse::HTTP::UserAgent::Constants qw(:all);
use Carp qw( croak );

BEGIN {
    constant->import( DEBUG => 0 ) if not defined &DEBUG;
}

my %OSFIX = (
    'WinNT4.0'       => 'Windows NT 4.0',
    'WinNT'          => 'Windows NT',
    'Win95'          => 'Windows 95',
    'Win98'          => 'Windows 98',
    'Windows NT 5.0' => 'Windows 2000',
    'Windows NT 5.1' => 'Windows XP',
    'Windows NT 5.2' => 'Windows Server 2003',
    'Windows NT 6.0' => 'Windows Vista / Server 2008',
    'Windows NT 6.1' => 'Windows 7',
);

sub new {
    my $class = shift;
    my $ua    = shift || croak "No user agent string specified";
    my $self  = [ map { undef } 0..MAXID ];
    bless $self, $class;
    $self->[UA_STRING] = $ua;
    $self->_parse;
    $self;
}

#------------------------------------------------------------------------------#

sub name    { shift->[UA_NAME]    || '' }
sub unknown { shift->[UA_UNKNOWN] || '' }
sub generic { shift->[UA_GENERIC] || '' }
sub os      { shift->[UA_OS]      || '' }
sub lang    { shift->[UA_LANG]    || '' }
sub robot   { shift->[UA_ROBOT]   || 0  }

sub original_name    { shift->[UA_ORIGINAL_NAME]    || '' }
sub original_version { shift->[UA_ORIGINAL_VERSION] || '' }

sub version {
    my $self = shift;
    my $type = shift || '';
    return $self->[ $type eq 'raw' ? UA_VERSION_RAW : UA_VERSION ] || 0;
}

sub mozilla {
    my $self = shift;
    return +() if ! $self->[UA_MOZILLA];
    my @rv = @{ $self->[UA_MOZILLA] };
    return wantarray ? @rv : $rv[0];
}

sub toolkit {
    my $self = shift;
    return +() if ! $self->[UA_TK];
    return @{ $self->[UA_TK] };
}

sub extras {
    my $self = shift;
    return +() if ! $self->[UA_EXTRAS];
    return @{ $self->[UA_EXTRAS] };
}

sub dotnet {
    my $self = shift;
    return +() if ! $self->[UA_DOTNET];
    return @{ $self->[UA_DOTNET] };
}

#TODO: new accessors
#strength
#wap
#mobile
#parser
#device

#------------------------------------------------------------------------------#

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
    $self->[IS_MAXTHON] = index(uc $self->[UA_STRING], 'MAXTHON') != -1;

    my $ua = $self->[UA_STRING];
    my($moz, $thing, $extra, @others) = split RE_SPLIT_PARSE, $ua;
    $thing = $thing ? [ split m{;\s?}xms, $thing ] : [];
    $extra = [ split m{ \s+}xms, $extra ] if $extra;

    $self->_debug_pre_parse( $moz, $thing, $extra, @others ) if DEBUG;
    $self->_do_parse($moz, $thing, $extra, @others);
    $self->[IS_PARSED]  = 1;

    return $self if $self->[UA_UNKNOWN];

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

    if ( $self->[UA_TK] ) {
        push @{ $self->[UA_TK] }, $self->_numify( $self->[UA_TK][1] );
    }

    if( $self->[UA_MOZILLA] ) {
        $self->[UA_MOZILLA] =~ tr/a-z://d;
        $self->[UA_MOZILLA] = [ $self->[UA_MOZILLA],
                                $self->_numify( $self->[UA_MOZILLA] ) ];
    }

    if ( $self->[UA_OS] ) {
        $self->[UA_OS] = $OSFIX{ $self->[UA_OS] } || $self->[UA_OS];
    }

    foreach my $robo ( LIST_ROBOTS ) {
        if ( lc($robo) eq lc($self->[UA_NAME]) ) {
            $self->[UA_ROBOT] = 1;
            last;
        }
    }

    return;
}

sub _do_parse {
    my $self = shift;
    my($m, $t, $e, @o) = @_;
    my $c = $t->[0] && $t->[0] eq 'compatible';

    if ( $c && shift @{$t} && ! $e && ! $self->[IS_MAXTHON] ) {
        my($n, $v) = split /\s+/, $t->[0];
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

    return $self->_extended_probe($m, $t, $e, $c, @o)
                if $self->can('_extended_probe');

    $self->[UA_UNKNOWN] = 1; # give up
    return;
}

sub _extended_probe {
    my $self = shift;
    my($moz, $thing, $extra, $compatible, @others) = @_;

    return if $self->_is_gecko        && $self->_parse_gecko( @_ );
    return if $self->_is_netscape(@_) && $self->_parse_netscape( @_ );
    return if $self->_is_generic(@_);

    $self->[UA_UNKNOWN] = 1;
    return;
}

sub _object_ids {
    return grep { m{ \A UA_ }xms } keys %Parse::HTTP::UserAgent::;
}

sub _numify {
    my $self = shift;
    my $v    = shift || return 0;
    #warn "NUMIFY: $v\n";
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
        my $w = shift;
        my $ok = $w !~ m{Integer overflow in version} &&
                 $w !~ m{Version string .+? contains invalid data; ignoring:};
        warn $w if $ok;
    };
    my $rv = qv($v)->numify;
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

=head1 NAME

Parse::HTTP::UserAgent - Parser for the User Agent string

=head1 SYNOPSIS

   use Parse::HTTP::UserAgent;
   my $ua = Parse::HTTP::UserAgent->new( $str );
   die "Unable to parse!" if $ua->unknown;
   print $ua->name;
   print $ua->version;
   print $ua->os;

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
MSIE, FireFox, Opera, Safari & Chrome first. If enabled, the extended
interface tries to identify Mozilla, Netscape, Robots and the rest will
be tried with a generic parser. The extended interface also includes a
structure dumper, useful for debugging.

=head1 METHODS

=head2 new STRING

Constructor. Takes the user agent string as the only parameter and returns
an object based on the parsed structure.

=head2 trim STRING

Trims the string.

=head2 as_hash

Returns a hash representation of the parsed structure.

=head2 accessors

Ther methods can be used to access the various parts of the parsed structure.

=head3 dotnet

=head3 extras

=head3 generic

=head3 lang

=head3 mozilla

=head3 name

=head3 original_name

=head3 original_version

=head3 os

=head2 robot

=head2 toolkit

=head2 unknown

=head2 version

=head1 SEE ALSO

=head2 Similar Functionality

L<HTTP::BrowserDetect>, L<HTML::ParseBrowser>, L<HTTP::DetectUserAgent>.

=head2 Resources

L<http://en.wikipedia.org/wiki/User_agent>,
L<http://www.zytrax.com/tech/web/browser_ids.htm>,
L<http://www.zytrax.com/tech/web/mobile_ids.html>,
L<http://www.webaim.org/blog/user-agent-string-history/>.

=cut
