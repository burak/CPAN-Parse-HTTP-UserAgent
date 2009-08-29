package Parse::HTTP::UserAgent::Constants;
use strict;
use vars qw( $VERSION $OID @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

$VERSION = '0.10';

BEGIN { $OID = -1 }
use constant UA_STRING           => ++$OID; # just for information
use constant UA_UNKNOWN          => ++$OID; # failed to detect?
use constant UA_GENERIC          => ++$OID; # parsed with a generic parser.
use constant UA_NAME             => ++$OID; # The identifier of the ua
use constant UA_VERSION_RAW      => ++$OID; # the parsed version
use constant UA_VERSION          => ++$OID; # used for numerical ops. via qv()
use constant UA_OS               => ++$OID; # Operating system
use constant UA_LANG             => ++$OID; # the language of the ua interface
use constant UA_TOOLKIT          => ++$OID; # [Opera] ua toolkit
use constant UA_EXTRAS           => ++$OID; # Extra stuff (Toolbars?) non parsable junk
use constant UA_DOTNET           => ++$OID; # [MSIE] List of .NET CLR versions
use constant UA_STRENGTH         => ++$OID; # [MSIE] List of .NET CLR versions
use constant UA_MOZILLA          => ++$OID; # [Firefox] Mozilla revision
use constant UA_ROBOT            => ++$OID; # Is this a robot?
use constant UA_WAP              => ++$OID; # unimplemented
use constant UA_MOBILE           => ++$OID; # unimplemented
use constant UA_PARSER           => ++$OID; # the parser name
use constant UA_DEVICE           => ++$OID; # the name of the mobile device
use constant UA_ORIGINAL_NAME    => ++$OID; # original name if this is some variation
use constant UA_ORIGINAL_VERSION => ++$OID; # original version if this is some variation
use constant IS_PARSED           => ++$OID; # _parse() happened or not
use constant IS_MAXTHON          => ++$OID; # Is this the dumb IE faker?
use constant IS_EXTENDED         => ++$OID;
use constant MAXID               =>   $OID;

use constant RE_FIREFOX_NAMES    => qr{Firefox|Iceweasel|Firebird|Phoenix }xms;
use constant RE_DOTNET           => qr{ \A [.]NET \s+ CLR \s+ (.+?) \z    }xms;
use constant RE_WINDOWS_OS       => qr{ \A Win(dows|NT|[0-9]+)?           }xmsi;
use constant RE_SLASH            => qr{ /                                 }xms;
use constant RE_SPLIT_PARSE      => qr{ \s? [()] \s?                      }xms;
use constant RE_OPERA_MINI       => qr{ \A (Opera \s+ Mini) / (.+?) \z    }xms;
use constant RE_TRIDENT          => qr{ \A (Trident) / (.+?) \z           }xmsi;
use constant RE_EPIPHANY_GECKO   => qr{ \A (Epiphany) / (.+?) \z          }xmsi;
use constant RE_WHITESPACE       => qr{ \s+ }xms;

use constant LIST_ROBOTS         => qw(
    Wget
    curl
    libwww-perl
    GetRight
    Googlebot
    Baiduspider+
    msnbot
), 'Yahoo! Slurp';

use Exporter ();

BEGIN {
    @ISA         = qw( Exporter );
    %EXPORT_TAGS = (
        object_ids => [qw(
            IS_PARSED
            IS_MAXTHON
            IS_EXTENDED
            UA_STRING
            UA_UNKNOWN
            UA_GENERIC
            UA_NAME
            UA_VERSION_RAW
            UA_VERSION
            UA_OS
            UA_LANG
            UA_TOOLKIT
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
            UA_ORIGINAL_VERSION
            MAXID
        )],
        re => [qw(
            RE_FIREFOX_NAMES
            RE_DOTNET
            RE_WINDOWS_OS
            RE_SLASH
            RE_SPLIT_PARSE
            RE_OPERA_MINI
            RE_TRIDENT
            RE_EPIPHANY_GECKO
            RE_WHITESPACE
        )],
        list => [qw(
            LIST_ROBOTS
        )],
    );

    @EXPORT_OK        = map { @{ $_ } } values %EXPORT_TAGS;
    $EXPORT_TAGS{all} = [ @EXPORT_OK ];
}

1;

__END__

=pod

=head1 NAME

Parse::HTTP::UserAgent::Constants - Various constants

=head1 DESCRIPTION

Internal module

=head1 SEE ALSO

L<Parse::HTTP::UserAgent>.

=cut
