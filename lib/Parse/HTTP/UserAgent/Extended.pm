package Parse::HTTP::UserAgent::Extended;
use strict;
use vars qw( $VERSION );
use Carp qw( croak    );
use Parse::HTTP::UserAgent qw(:object_ids);
use constant RE_ROBOTS => qr{
    \A
        (
              Wget
            | libwww\-perl
            | GetRight
            | Googlebot
        )
        /
        (.+)
    \z
}xmsi;

$VERSION = '0.10';

sub _extended_probe {
    my $self = shift;
    my($moz, $thing, $extra, $compatible, @others) = @_;

    return if $self->_is_gecko        && $self->_parse_gecko(@_);
    return if $self->_is_netscape(@_) && $self->_parse_netscape(@_);
    return if $self->_is_robot;
    return if $self->_is_generic(@_);

    $self->[UA_UNKNOWN] = 1;
    return;
}

sub _is_gecko {
    my $self = shift;
    return index($self->[UA_STRING], 'Gecko/') != -1;
}

sub _is_generic {
    my $self = shift;
#    local $Data::Dumper::Indent = 0;use Data::Dumper; warn Dumper(\@_).Dumper([$mname, $mversion, @remainder])."\n";
    return 1 if $self->_generic_name_version(@_) ||
                $self->_generic_compatible(@_)   ||
                $self->_generic_moz_thing(@_);
    return;
}

sub _is_netscape {
    my $self = shift;
    my($moz, $thing, $extra, $compatible, @others) = @_;

    my $rv = index($moz, 'Mozilla/') != -1 &&
             $moz ne 'Mozilla/4.0'         &&
             ! $compatible                 &&
             ! $extra                      &&
             ! @others                     &&
             $thing->[-1] ne 'Sun' # hotjava
             ;
    return $rv;
}

sub _parse_gecko {
    my $self = shift;
    my($moz, $thing, $extra, @others) = @_;
        $self->_parse_mozilla_family($moz, $thing, $extra, @others);
        # we got some name & version
        if ( $self->[UA_NAME] && $self->[UA_VERSION_RAW] ) {
            # Change SeaMonkey too?
            warn "DDDDDD:" . $self->[UA_NAME] . "\n";
            $self->[UA_NAME]   = 'Netscape' if $self->[UA_NAME] eq 'Netscape6';
            $self->[UA_NAME]   = 'Mozilla'  if $self->[UA_NAME] eq 'Beonex';
            $self->[UA_PARSER] = 'mozilla_family -> generic';
            return 1 ;
        }
        if ( $self->[UA_TK] && $self->[UA_TK][0] eq 'Gecko' ) {
            ($self->[UA_NAME], $self->[UA_VERSION_RAW]) = split m{/}xms, $moz;
            if ( $self->[UA_NAME] && $self->[UA_VERSION_RAW] ) {
                $self->[UA_PARSER] = 'mozilla_family -> gecko';
                return 1;
            }
        }
    return;
}

sub _parse_netscape {
    my $self = shift;
    my($moz, $thing) = @_;

        my($mozx, $junk)     = split m{ \s+ }xms, $moz;
        my(undef, $version) = split m{ /   }xms, $mozx;
        my @buf;
        foreach my $e ( @{ $thing } ) {
            if ( $self->_is_strength($e) ) {
                $self->[UA_STRENGTH] = $e;
                next;
            }
            push @buf, $e;
        }
        $self->[UA_VERSION_RAW] = $version;
        $self->[UA_OS]   = shift @buf;
        $self->[UA_NAME] = 'Netscape';
        if ( $junk ) {
            $junk =~ s{ \[ (.+?) \] .* \z}{$1}xms;
            $self->[UA_LANG] = $junk if $junk;
        }
        $self->[UA_PARSER] = 'netscape';
        return 1;

}

sub _generic_moz_thing {
    my $self = shift;
    my($moz, $thing, $extra, $compatible, @others) = @_;
    return if ! @{ $thing };
    my($mname, $mversion, @remainder) = split m{[/\s]}xms, $moz;
    return if $mname eq 'Mozilla';

    $self->[UA_NAME]        = $mname;
    $self->[UA_VERSION_RAW] = $mversion || ( $mname eq 'Links' ? shift @{$thing} : 0 );
    $self->[UA_OS]          = @remainder ? join(' ', @remainder)
                            : $thing->[0] && $thing->[0] !~ m{\d+[.]?\d} ? shift @{$thing}
                            :              undef;
    my @extras = (@{$thing}, $extra ? @{$extra} : (), @others );
    $self->[UA_EXTRAS]      = [ @extras ] if @extras;
    $self->[UA_GENERIC]     = 1;
    $self->[UA_PARSER]      = 'generic_moz_thing';

    return 1;
}

sub _generic_name_version {
    my $self = shift;
    my($moz, $thing, $extra, $compatible, @others) = @_;
    my $ok = $moz && ! @{$thing} && ! $extra && ! $compatible && ! @others;
    return if not $ok;

    my @moz = split m{\s}xms, $moz;
    if ( @moz == 1 ) {
        my($name, $version) = split m{/}xms, $moz;
        if ($name && $version) {
            $self->[UA_NAME]        = $name;
            $self->[UA_VERSION_RAW] = $version;
            $self->[UA_GENERIC]     = 1;
            $self->[UA_PARSER]      = 'generic_name_version';
            return 1;
        }
    }
    return;
}

sub _generic_compatible {
    my $self = shift;
    my($moz, $thing, $extra, $compatible, @others) = @_;

    return if ! ( $compatible && @{$thing} );

    my($mname, $mversion) = split m{[/\s]}xms, $moz;
    my($name, $version)   = $mname eq 'Mozilla'
                          ? split( m{[/\s]}xms, shift @{ $thing } )
                          : ($mname, $mversion)
                          ;
    my $junk   = shift @{$thing}
                    if  $thing->[0] &&
                      ( $thing->[0] eq $name || $thing->[0] eq $moz);
    my $os     = shift @{$thing};
    my $lang   = pop   @{$thing};
    my @extras;

    if ( $name eq 'MSIE') {
        if ( $extra ) { # Sleipnir?
            ($name, $version) = split m{/}xms, pop @{$extra};
            my($extras,$dotnet) = $self->_extract_dotnet( $thing, $extra );
            $self->[UA_DOTNET] = [ @{$dotnet} ] if @{$dotnet};
            @extras = (@{ $extras }, @others);
        }
        else {
            return if index($moz, ' ') != -1; # WebTV
        }
    }

    @extras = (@{$thing}, $extra ? @{$extra} : (), @others ) if ! @extras;

    $self->[UA_NAME]        = $name;
    $self->[UA_VERSION_RAW] = $version || 0;
    $self->[UA_OS]          = $os;
    $self->[UA_LANG]        = $lang;
    $self->[UA_EXTRAS]      = [ @extras ] if @extras;
    $self->[UA_GENERIC]     = 1;
    $self->[UA_PARSER]      = 'generic_compatible';

    return 1;
}

sub _is_robot {
    # regex yerine parser!!!
    my $self = shift;
    my $ua   = $self->[UA_STRING];
    if ( my @m = $ua =~ RE_ROBOTS ) {
        $self->[UA_NAME]        = $m[0];
        my($v, undef)           = split m{\s+}xms, $m[1];
        $self->[UA_VERSION_RAW] = $v;
        $self->[UA_ROBOT]       = 1;
        $self->[UA_PARSER]      = 'robot';
        return 1;
    }
    return;
}

1;

__END__
