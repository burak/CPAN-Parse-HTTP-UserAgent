package Parse::HTTP::UserAgent;
use strict;
use vars qw( $VERSION @ISA $OID @EXPORT @EXPORT_OK %EXPORT_TAGS );

$VERSION = '0.10';

BEGIN { $OID = -1 }
use constant UA_STRING      => ++$OID; # just for information
use constant IS_PARSED      => ++$OID; # _parse() happened or not
use constant UA_UNKNOWN     => ++$OID; # failed to detect?
use constant UA_GENERIC     => ++$OID; # parsed with a generic parser.
use constant UA_NAME        => ++$OID; # The identifier of the ua
use constant UA_VERSION_RAW => ++$OID; # the parsed version
use constant UA_VERSION     => ++$OID; # used for numerical ops. via qv()
use constant UA_OS          => ++$OID; # Operating system
use constant UA_LANG        => ++$OID; # the language of the ua interface
use constant UA_TK          => ++$OID; # [Opera] ua toolkit
use constant UA_EXTRAS      => ++$OID; # Extra stuff (Toolbars?). non parsable junk
use constant UA_DOTNET      => ++$OID; # [MSIE] List of .NET CLR versions
use constant UA_STRENGTH    => ++$OID; # [MSIE] List of .NET CLR versions
use constant UA_MOZILLA     => ++$OID; # [Firefox] Mozilla revision
use constant UA_ROBOT       => ++$OID; # Is this a robot?
use constant UA_WAP         => ++$OID; # unimplemented
use constant UA_MOBILE      => ++$OID; # unimplemented
use constant UA_PARSER      => ++$OID; # the parser name
use constant UA_DEVICE      => ++$OID; # the name of the mobile device
use constant UA_ORIGINAL_NAME => ++$OID; # the name of the mobile device
use constant MAXID          =>   $OID;

use constant RE_FIREFOX_NAMES => qr{Firefox|Iceweasel|Firebird|Phoenix}xms;

use overload '""',    => 'name',
             '0+',    => 'version',
             fallback => 1,
;
use version;
use Carp qw( croak );
use Exporter ();

BEGIN {
    *DEBUG = sub () { 0 } if not defined &DEBUG;
}

@ISA         = qw( Exporter );
%EXPORT_TAGS = (
    object_ids =>   [qw(
                        IS_PARSED
                        UA_STRING
                        UA_UNKNOWN
                        UA_GENERIC
                        UA_NAME
                        UA_VERSION_RAW
                        UA_VERSION
                        UA_OS
                        UA_LANG
                        UA_TK
                        UA_EXTRAS
                        UA_DOTNET
                        UA_MOZILLA
                        UA_STRENGTH
                        UA_ROBOT
                        UA_WAP
                        UA_MOBILE
                        UA_PARSER
                        UA_DEVICE
                        UA_ORIGINAL_NAME
                        MAXID
                    )],
);

@EXPORT_OK = map { @{ $_ } } values %EXPORT_TAGS;

my %OSFIX = (
    'WinNT4.0'       => 'Windows NT 4.0',
    'WinNT'          => 'Windows NT',
    'Win95'          => 'Windows 95',
    'Win98'          => 'Windows 98',
    'Windows NT 5.0' => 'Windows 2000',
    'Windows NT 5.1' => 'Windows XP',
    'Windows NT 5.2' => 'Windows Server 2003',
    'Windows NT 6.0' => 'Windows Vista / Server 2008',
);

sub import {
    my $class = shift;
    my @args;
    my %extend = map { $_ => 0 } qw( -dumper -extended ); # -probe
    my $all    = 0;
    foreach my $e ( @_ ) {
        $extend{$e}++, next if exists $extend{ $e };
        $all++       , next if $e eq '-all';
        push @args, $e;
    }

    foreach my $mod ( keys %extend ) {
        next if ! $extend{ $mod } && ! $all;
        $class->_extend( $mod );
    }

    return $class->export_to_level(1, $class, @args);
}

sub new {
    my $class = shift;
    my $ua    = shift || croak "No user agent string specified";
    my $self  = [ map { undef } 0..MAXID ];
    bless $self, $class;
    $self->[UA_STRING] = $ua;
    $self->_parse;
    $self;
}

sub _object_ids { grep { m{ \A UA_ }xms } @{ $EXPORT_TAGS{object_ids} } }

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

sub name    { shift->[UA_NAME]    || '' }
sub unknown { shift->[UA_UNKNOWN] || '' }
sub generic { shift->[UA_GENERIC] || '' }
sub os      { shift->[UA_OS]      || '' }
sub lang    { shift->[UA_LANG]    || '' }
sub robot   { shift->[UA_ROBOT]   || 0  }

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

sub trim {
    my $self = shift;
    my $s    = shift;
    return $s if ! $s;
    $s =~ s{ \A \s+    }{}xms;
    $s =~ s{    \s+ \z }{}xms;
    return $s;
}

sub _extend {
    my $class = shift;
    (my $mod  = shift) =~ tr/-//d;
    $mod = __PACKAGE__ . '::' . ucfirst($mod);
    return if $class->isa( $mod );
    (my $file = $mod) =~ s{::}{/}xmsg;
    require $file . '.pm';
    push @ISA, $mod;
    return 1;
}

sub _is_strength {
    my $self = shift;
    my $s    = shift || return;
       $s    = $self->trim( $s );
    return $s if $s eq 'U' || $s eq 'I' || $s eq 'N';
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

sub _parse {
    my $self = shift;
    return $self if $self->[IS_PARSED];

    my $ua   = $self->[UA_STRING];
    my($moz, $thing, $extra, @others) = split m{\s?[()]\s?}xms, $ua;
    $thing   = $thing ? [ split m{;\s?}xms, $thing ] : [];
    $extra   = [ split m{ \s+}xms, $extra ] if $extra;

    $self->_debug_pre_parse($moz, $thing, $extra, @others) if DEBUG;

    $self->_do_parse($moz, $thing, $extra, @others);
    $self->[IS_PARSED]  = 1;
    return $self if $self->[UA_UNKNOWN];

    $self->[UA_VERSION] = $self->_numify($self->[UA_VERSION_RAW])
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

    push @{ $self->[UA_TK] }, $self->_numify($self->[UA_TK][1]) if $self->[UA_TK];

    if( $self->[UA_MOZILLA] ) {
        $self->[UA_MOZILLA] =~ tr/a-z://d;
        $self->[UA_MOZILLA] = [ $self->[UA_MOZILLA],
                                $self->_numify($self->[UA_MOZILLA]) ];
    }

    if ( $self->[UA_OS] ) {
        $self->[UA_OS] = $OSFIX{ $self->[UA_OS] } || $self->[UA_OS];
    }

    return;
}

sub _do_parse {
    my $self = shift;
    my($m, $t, $e, @o) = @_;
    my $c = $t->[0] && $t->[0] eq 'compatible';

    if ( $c && shift @{$t} && ! $e ) {
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
            : undef;

    if ( $rv ) {
        my $pname  = shift( @{ $rv } );
        my $method = '_parse_' . $pname;
        $self->[UA_PARSER] = $pname;
        return $self->$method( @{ $rv } );
    }

    return $self->_extended_probe($m, $t, $e, $c, @o)
                if $self->can('_extended_probe');

    $self->[UA_UNKNOWN] = 1;
    return;
}

sub _is_opera_pre {
    my $self = shift;
    my $moz = shift;
    return index( $moz, "Opera") != -1;
}

sub _is_opera_post {
    my $self = shift;
    my $extra = shift;
    return $extra && $extra->[0] eq 'Opera';
}

sub _is_opera_ff { # opera faking as firefox
    my $self = shift;
    my $extra = shift;
    return $extra && @{$extra} == 4 && $extra->[2] eq 'Opera';
}

sub _is_safari {
    my $self   = shift;
    my $extra  = shift;
    my $others = shift;
    return index($self->[UA_STRING],'Chrome') == -1 && (
                    ( $extra  && index( $extra->[0], "AppleWebKit")  != -1 ) ||
                    ( @{$others} && index( $others->[-1], "Safari" ) != -1 )
                   );
}

sub _is_chrome {
    my $self   = shift;
    my $extra  = shift;
    my $others = shift;
    my $chx    = $others->[1] || return;
    my($chrome, $safari) = split m{\s}xms, $chx;
    return if ! ( $chrome && $safari);

    return index($chrome,'Chrome') != -1 &&
           index($safari,'Safari') != -1 &&
           ( $extra  && index( $extra->[0], "AppleWebKit") != -1);
}

sub _is_ff {
    my $self = shift;
    my $extra = shift;
    return $extra && $extra->[1] && (
                    ($extra->[1] eq 'Mozilla' && $extra->[2])
                        ? $extra->[2] =~ RE_FIREFOX_NAMES
                                && do { $extra->[1] = $extra->[2] }
                        : $extra->[1] =~ RE_FIREFOX_NAMES
                 );
}

sub _extract_dotnet {
    my $self = shift;
    my @raw  = map { ref($_) eq 'ARRAY' ? @{$_} : $_ } grep { $_ } @_;
    my(@extras,@dotnet);

    foreach my $e ( @raw ) {
        if ( my @match = $e =~ m{ \A [.]NET \s+ CLR \s+ (.+?) \z }xms ) {
            push @dotnet, $match[0];
            next;
        }
        if ( $e =~ m{ \A Win(?:dows|NT|[0-9]+)? }xmsi ) {
            $self->[UA_OS] = $e;
            next;
        }
        push @extras, $e;
    }

    return [@extras], [@dotnet];
}

sub _parse_msie {
    my $self = shift;
    my($moz, $thing, $extra, $name, $version) = @_;
    my $junk = shift @{ $thing }; # already used
    # "Microsoft Internet Explorer";

    my($extras,$dotnet) = $self->_extract_dotnet( $thing, $extra );

    if ( @{$extras} == 2 && index( $extras->[1], 'Lunascape' ) != -1 ) {
        ($name, $version) = split m{[/\s]}xms, pop @{ $extras };
    }

    $self->[UA_NAME]        = $name;
    $self->[UA_VERSION_RAW] = $version;
    $self->[UA_DOTNET]      = [ @{ $dotnet } ] if @{$dotnet};
    $self->[UA_EXTRAS]      = [ @{ $extras } ];
    my $e = $self->[UA_EXTRAS];
    if ( $e->[0] && $e->[0] eq 'Mac_PowerPC' ) {
        $self->[UA_OS] = shift @{ $self->[UA_EXTRAS] };
    }
    return;
}

sub _parse_firefox {
    my $self = shift;
    $self->_parse_mozilla_family( @_ );
    $self->[UA_NAME] = 'Firefox';
    return;
}

sub _parse_safari {
    my $self = shift;
    my($moz, $thing, $extra, @others) = @_;
    $self->[UA_NAME]         = 'Safari';
    my($version, @junk)      = split m{\s+}xms, pop @others;
    (undef, $version)        = split m{/}xms, $version;
    $self->[UA_NAME]         = 'Safari';
    $self->[UA_VERSION_RAW]  = $version;
    $self->[UA_TK]           = [ split m{/}, $extra->[0] ];
    $self->[UA_LANG]         = pop @{ $thing };
    $self->[UA_OS]           = length $thing->[-1] > 1 ? pop @{ $thing }
                                                       : shift @{$thing}
                             ;
    $self->[UA_DEVICE]       = shift @{$thing} if $thing->[0] eq 'iPhone';
    $self->[UA_EXTRAS]       = [ @{$thing}, @others ];

    if ( length($self->[UA_OS]) == 1 ) {
        push @{$self->[UA_EXTRAS]}, $self->[UA_EXTRAS];
        $self->[UA_OS] = undef;
    }

    push @{$self->[UA_EXTRAS]}, @junk if @junk;

    return;
}

sub _parse_chrome {
    my $self = shift;
    my($moz, $thing, $extra, @others) = @_;
    my $chx = pop @others;
    my($chrome, $safari)     = split m{\s}xms, $chx;
    push @others, $safari;
    $self->_parse_safari($moz, $thing, $extra, @others);
    my($name, $version)      = split m{/}xms, $chrome;
    $self->[UA_NAME]         = $name;
    $self->[UA_VERSION_RAW]  = $version;
    return;
}

sub _parse_opera_pre {
    # opera 5,9
    my $self                 = shift;
    my($moz, $thing, $extra) = @_;
    my($name, $version)      = split m{/}xms, $moz;
    my $faking_ff = index($thing->[-1], "rv:") != -1 ? pop @{$thing} : 0;
    $self->[UA_NAME]         = $name;
    $self->[UA_VERSION_RAW]  = $version;
   ($self->[UA_LANG]         = pop @{$extra}) =~ tr/[]//d if $extra;

    $self->[UA_LANG]       ||= pop @{$thing} if $faking_ff;

    if ( qv($version) >= 9 && length($self->[UA_LANG]) > 5 ) {
        $self->[UA_TK]   = [ split m{/}, $self->[UA_LANG] ];
       ($self->[UA_LANG] = pop @{$thing}) =~ tr/[]//d if $extra;
    }

    $self->[UA_OS]     = $self->_is_strength($thing->[-1]) ? shift @{$thing}
                       :                                     pop   @{$thing}
                       ;

    $self->[UA_EXTRAS] = [ @{ $thing }, ( $extra ? @{$extra} : () ) ];
    return;
}

sub _parse_opera_post {
    # opera 5,6,7
    my $self = shift;
    my($moz, $thing, $extra, $compatible) = @_;
    shift @{ $thing } if $compatible;
    $self->[UA_NAME]        = shift @{$extra};
    $self->[UA_VERSION_RAW] = shift @{$extra};
   ($self->[UA_LANG]        = shift @{$extra} || '') =~ tr/[]//d;
    $self->[UA_OS]          = $self->_is_strength($thing->[-1]) ? shift @{$thing}
                            :                                     pop   @{$thing}
                            ;
    $self->[UA_EXTRAS]      = [ @{ $thing }, ( $extra ? @{$extra} : () ) ];
    return;
}

sub _parse_mozilla_family {
    my $self = shift;
    my($moz, $thing, $extra, @extras) = @_;
    # firefox variation or just mozilla itself
    my($name, $version)      = split m{/}xms, defined $extra->[1] ? $extra->[1]
                             :                                      $moz
                             ;
    $self->[UA_NAME]         = $name;
    $self->[UA_TK]           = [ split m{/}xms, $extra->[0] ];
    $self->[UA_VERSION_RAW]  = $version;

    if ( index($thing->[-1], 'rv:') != -1 ) {
        $self->[UA_MOZILLA] = pop @{ $thing };
        $self->[UA_LANG]    = pop @{ $thing };
        $self->[UA_OS]      = pop @{ $thing };
    }

    $self->[UA_EXTRAS] = [ @{ $thing }, @extras ];
    return;
}

1;

__END__

=head1 NAME

Parse::HTTP::UserAgent - Parse The User Agent String

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

=head2 new

=head2 accessors

=head1 AUTHOR

Burak Gursoy <burakE<64>cpan.org>.

=head1 LICENSE



=head1 SEE ALSO

L<HTTP::BrowserDetect>, L<HTML::ParseBrowser>,
L<HTTP::DetectUserAgent>, 
L<http://en.wikipedia.org/wiki/User_agent>,
L<http://www.zytrax.com/tech/web/browser_ids.htm>,
L<http://www.webaim.org/blog/user-agent-string-history/>.

=cut
