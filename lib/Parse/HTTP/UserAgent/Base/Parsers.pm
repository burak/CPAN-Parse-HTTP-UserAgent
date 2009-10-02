package Parse::HTTP::UserAgent::Base::Parsers;
use strict;
use warnings;
use vars qw( $VERSION );
use Parse::HTTP::UserAgent::Constants qw(:all);
use constant ERROR_MAXTHON_VERSION => 'Unable to extract Maxthon version from Maxthon UA-string';
use constant ERROR_MAXTHON_MSIE    => 'Unable to extract MSIE from Maxthon UA-string';
use constant OPERA9                => 9;
use constant OPERA_TK_LENGTH       => 5;

$VERSION = '0.10';

sub _extract_dotnet {
    my($self, @args) = @_;
    my @raw  = map { ref($_) eq 'ARRAY' ? @{$_} : $_ } grep { $_ } @args;
    my(@extras,@dotnet);

    foreach my $e ( @raw ) {
        if ( my @match = $e =~ RE_DOTNET ) {
            push @dotnet, $match[0];
            next;
        }
        if ( $e =~ RE_WINDOWS_OS && $1 ne '64' ) {
            $self->[UA_OS] = $e;
            next;
        }
        push @extras, $e;
    }

    return [@extras], [@dotnet];
}

sub _fix_opera {
    my $self = shift;
    return if ! $self->[UA_EXTRAS];
    my @buf;
    foreach my $e ( @{ $self->[UA_EXTRAS] } ) {
        if ( $e =~ RE_OPERA_MINI ) {
            $self->[UA_ORIGINAL_NAME]    = $1;
            $self->[UA_ORIGINAL_VERSION] = $2;
            $self->[UA_MOBILE]           = 1;
            next;
        }
        push @buf, $e;
    }
    $self->_fix_os_lang;
    $self->_fix_windows_nt('skip_os');
    $self->[UA_EXTRAS] = [ @buf ];
    return;
}

sub _fix_generic {
    my($self, $os_ref, $name_ref, $v_ref, $e_ref) = @_;
    if ( ${$v_ref} && ${$v_ref} !~ RE_DIGIT) {
        ${$name_ref} .= q{ } . ${$v_ref};
        ${$v_ref}     = undef;
    }

    if ( ${$os_ref} && ${$os_ref} =~ RE_HTTP ) {
        ${$os_ref} =~ s{ \A \+ }{}xms;
        push @{ $e_ref }, ${$os_ref};
        ${$os_ref} = undef;
    }
    return;
}

sub _parse_maxthon {
    my($self, $moz, $thing, $extra, @others) = @_;
    my @omap = grep { $_ } map { split RE_SC_WS_MULTI, $_ } @others;
    my($maxthon, $msie, @buf);
    foreach my $e ( @omap, @{$thing} ) { # $extra -> junk
        if ( index(uc $e, 'MAXTHON') != NO_IMATCH ) { $maxthon = $e; next; }
        if ( index(uc $e, 'MSIE'   ) != NO_IMATCH ) { $msie    = $e; next; }
        push @buf, $e;
    }

    if ( ! $maxthon ) {
        warn ERROR_MAXTHON_VERSION . "\n";
        $self->[UA_UNKNOWN] = 1;
        return;
    }

    if ( ! $msie ) {
        warn ERROR_MAXTHON_MSIE . "\n";
        $self->[UA_UNKNOWN] = 1;
        return;
    }

    $self->_parse_msie($moz, [ undef, @buf ], undef, split RE_WHITESPACE, $msie);

    my(undef, $mv) = split RE_WHITESPACE, $maxthon;
    my $v = $mv      ? $mv
          : $maxthon ? '1.0'
          :            do { warn ERROR_MAXTHON_VERSION . "\n"; 0 }
          ;

    $self->[UA_ORIGINAL_VERSION] = $v;
    $self->[UA_ORIGINAL_NAME]    = 'Maxthon';
    return;
}

sub _parse_msie {
    my($self, $moz, $thing, $extra, $name, $version) = @_;
    my $junk = shift @{ $thing }; # already used
    my($extras,$dotnet) = $self->_extract_dotnet( $thing, $extra );

    if ( @{$extras} == 2 && index( $extras->[1], 'Lunascape' ) != NO_IMATCH ) {
        ($name, $version) = split RE_CHAR_SLASH_WS, pop @{ $extras };
    }

    $self->[UA_NAME]        = $name;
    $self->[UA_VERSION_RAW] = $version;
    $self->[UA_DOTNET]      = [ @{ $dotnet } ] if @{$dotnet};

    if ( $extras->[0] && $extras->[0] eq 'Mac_PowerPC' ) {
        $self->[UA_OS] = shift @{ $extras };
    }

    my @buf;
    foreach my $e ( @{ $extras } ) {
        if ( $e =~ RE_TRIDENT ) {
            $self->[UA_TOOLKIT] = [ $1, $2 ];
            next;
        }
        push @buf, $e;
    }
    $self->[UA_EXTRAS] = [ @buf ];
    $self->[UA_PARSER] = 'msie';
    return;
}

sub _parse_firefox {
    my($self, @args) = @_;
    $self->_parse_mozilla_family( @args );
    $self->[UA_NAME] = 'Firefox';
    return;
}

sub _parse_safari {
    my($self, $moz, $thing, $extra, @others) = @_;
    my($version, @junk)     = split RE_WHITESPACE, pop @others;
    my $ep = $version && index( lc($version), 'epiphany' ) != NO_IMATCH;
    (undef, $version)       = split RE_SLASH, $version;
    $self->[UA_NAME]        = $ep ? 'Epiphany' : 'Safari';
    $self->[UA_VERSION_RAW] = $version;
    $self->[UA_TOOLKIT]     = [ split RE_SLASH, $extra->[0] ];
    $self->[UA_LANG]        = pop @{ $thing };
    $self->[UA_OS]          = length $thing->[LAST_ELEMENT] > 1
                            ? pop   @{ $thing }
                            : shift @{ $thing }
                            ;
    $self->[UA_DEVICE]      = shift @{$thing} if $thing->[0] eq 'iPhone';
    $self->[UA_EXTRAS]      = [ @{$thing}, @others ];

    if ( length($self->[UA_OS]) == 1 ) {
        push @{$self->[UA_EXTRAS]}, $self->[UA_EXTRAS];
        $self->[UA_OS] = undef;
    }

    push @{$self->[UA_EXTRAS]}, @junk if @junk;

    return;
}

sub _parse_chrome {
    my($self, $moz, $thing, $extra, @others) = @_;
    my $chx                  = pop @others;
    my($chrome, $safari)     = split RE_WHITESPACE, $chx;
    push @others, $safari;
    $self->_parse_safari($moz, $thing, $extra, @others);
    my($name, $version)      = split RE_SLASH, $chrome;
    $self->[UA_NAME]         = $name;
    $self->[UA_VERSION_RAW]  = $version;
    return;
}

sub _parse_opera_pre {
    # opera 5,9
    my($self, $moz, $thing, $extra) = @_;
    my($name, $version)     = split RE_SLASH, $moz;
    my $faking_ff           = index($thing->[LAST_ELEMENT], 'rv:') != NO_IMATCH ? pop @{$thing} : 0;
    $self->[UA_NAME]        = $name;
    $self->[UA_VERSION_RAW] = $version;
    my $ver = $self->_numify( $version );
    my $lang;

    if ( $extra ) {
        # http://dev.opera.com/articles/view/opera-ua-string-changes/
        my $swap = index($extra->[LAST_ELEMENT], 'Version/') != NO_IMATCH; # damned 10.0 beta
        ($lang = $swap ? shift @{$extra} : pop @{$extra}) =~ tr/[]//d;
        if ( $swap ) {
            my $vjunk = pop @{$extra};
            $self->[UA_VERSION_RAW] = ( split RE_SLASH, $vjunk )[1] if $vjunk;
        }
    }

    $lang ||= pop @{$thing} if $faking_ff;

    if ( ! $self->[UA_TOOLKIT] && $ver >= OPERA9 && $lang && length( $lang ) > OPERA_TK_LENGTH ) {
        $self->[UA_TOOLKIT] = [ split RE_SLASH, $lang ];
       ($lang = pop @{$thing}) =~ tr/[]//d if $extra;
    }

    $self->[UA_LANG] = $lang;
    $self->[UA_OS]   = @{$thing} && $self->_is_strength( $thing->[LAST_ELEMENT] )
                     ? shift @{$thing}
                     : pop   @{$thing}
                     ;

    $self->[UA_EXTRAS] = [ @{ $thing }, ( $extra ? @{$extra} : () ) ];
    return $self->_fix_opera;
}

sub _parse_opera_post {
    # opera 5,6,7
    my($self, $moz, $thing, $extra, $compatible) = @_;
    shift @{ $thing } if $compatible;
    $self->[UA_NAME]        = shift @{$extra};
    $self->[UA_VERSION_RAW] = shift @{$extra};
   ($self->[UA_LANG]        = shift @{$extra} || q{}) =~ tr/[]//d;
    $self->[UA_OS]          = $self->_is_strength($thing->[LAST_ELEMENT])
                            ? shift @{$thing}
                            : pop   @{$thing}
                            ;
    $self->[UA_EXTRAS]      = [ @{ $thing }, ( $extra ? @{$extra} : () ) ];
    return $self->_fix_opera;
}

sub _parse_mozilla_family {
    my($self, $moz, $thing, $extra, @extras) = @_;
    # firefox variation or just mozilla itself
    my($name, $version)      = split RE_SLASH, defined $extra->[1] ? $extra->[1]
                             :                                       $moz
                             ;
    $self->[UA_NAME]         = $name;
    $self->[UA_TOOLKIT]      = [ split RE_SLASH, $extra->[0] ];
    $self->[UA_VERSION_RAW]  = $version;

    if ( index($thing->[LAST_ELEMENT], 'rv:') != NO_IMATCH ) {
        $self->[UA_MOZILLA]  = pop @{ $thing };
        $self->[UA_LANG]     = pop @{ $thing };
        $self->[UA_OS]       = pop @{ $thing };
    }

    $self->[UA_EXTRAS] = [ @{ $thing }, @extras ];
    return;
}

sub _parse_gecko {
    my($self, $moz, $thing, $extra, @others) = @_;
    $self->_parse_mozilla_family($moz, $thing, $extra, @others);

    # we got some name & version
    if ( $self->[UA_NAME] && $self->[UA_VERSION_RAW] ) {
        # Change SeaMonkey too?
        my $before = $self->[UA_NAME];
        $self->[UA_NAME]   = 'Netscape' if $self->[UA_NAME] eq 'Netscape6';
        $self->[UA_NAME]   = 'Mozilla'  if $self->[UA_NAME] eq 'Beonex';
        $self->[UA_PARSER] = 'mozilla_family:generic';
        my @buf;

        foreach my $e ( @{ $self->[UA_EXTRAS] } ) {
            next if ! $e;
            if ( my $s = $self->_is_strength($e) ) {
                $self->[UA_STRENGTH] = $s;
                next;
            }
            if ( $e =~ RE_IX86 ) {
                my($os,$lang) = split RE_COMMA, $e;
                $self->[UA_OS]   = $os   if $os;
                $self->[UA_LANG] = $self->trim($lang) if $lang;
                next;
            }
            if ( ! $self->[UA_OS] && $e =~ m{ Win(?:NT|dows) }xmsi ) {
                $self->[UA_OS] = $e;
                next;
            }
            if ( $e =~ RE_TWO_LETTER_LANG ) {
                $self->[UA_LANG] = $e;
                next;
            }
            if ( $e =~ RE_EPIPHANY_GECKO ) {
                $self->[UA_NAME]        = $before = $1;
                $self->[UA_VERSION_RAW] = $2;
            }
            push @buf, $e;
        }

        $self->[UA_EXTRAS]        = [ @buf ];
        $self->[UA_ORIGINAL_NAME] = $before if $before ne $self->[UA_NAME];
        $self->_fix_windows_nt;
        return 1 ;
    }

    if ( $self->[UA_TOOLKIT] && $self->[UA_TOOLKIT][TK_NAME] eq 'Gecko' ) {
        ($self->[UA_NAME], $self->[UA_VERSION_RAW]) = split RE_SLASH, $moz;
        if ( $self->[UA_NAME] && $self->[UA_VERSION_RAW] ) {
            $self->[UA_PARSER] = 'mozilla_family:gecko';
            return 1;
        }
    }

    return;
}

sub _fix_os_lang {
    my $self = shift;
    if ( $self->[UA_OS] && length $self->[UA_OS] == 2 ) {
        $self->[UA_LANG] = $self->[UA_OS];
        $self->[UA_OS]   = undef;
    }
    return;
}

sub _fix_windows_nt {
    my $self    = shift;
    my $skip_os = shift; # ie os can be undef
    my $os      = $self->[UA_OS] || q{};
    return if ( ! $os              && ! $skip_os )
        ||    (   $os ne 'windows' && ! $skip_os )
        ||      ! $self->[UA_EXTRAS][0]
        ||        $self->[UA_EXTRAS][0] !~ m{ NT\s?(\d.*?) \z }xmsi;
    $self->[UA_EXTRAS][0] = $self->[UA_OS]; # restore
    $self->[UA_OS] = "Windows NT $1"; # fix
    return;
}

sub _parse_netscape {
    my($self, $moz, $thing) = @_;
    my($mozx, $junk)    = split RE_WHITESPACE, $moz;
    my(undef, $version) = split RE_SLASH     , $mozx;
    my @buf;
    foreach my $e ( @{ $thing } ) {
        if ( my $s = $self->_is_strength($e) ) {
            $self->[UA_STRENGTH] = $s;
            next;
        }
        push @buf, $e;
    }
    $self->[UA_VERSION_RAW] = $version;
    $self->[UA_OS]          = $buf[0] eq 'X11' ? pop @buf : shift @buf;
    $self->[UA_NAME]        = 'Netscape';
    $self->[UA_EXTRAS]      = [ @buf ];
    if ( $junk ) {
        $junk =~ s{ \[ (.+?) \] .* \z}{$1}xms;
        $self->[UA_LANG] = $junk if $junk;
    }
    $self->[UA_PARSER] = 'netscape';
    return 1;
}

sub _generic_moz_thing {
    my($self, $moz, $t, $extra, $compatible, @others) = @_;
    return if ! @{ $t };
    my($mname, $mversion, @rest) = split RE_CHAR_SLASH_WS, $moz;
    return if $mname eq 'Mozilla';

    $self->[UA_NAME]        = $mname;
    $self->[UA_VERSION_RAW] = $mversion || ( $mname eq 'Links' ? shift @{$t} : 0 );
    $self->[UA_OS] = @rest                                     ? join(q{ }, @rest)
                   : $t->[0] && $t->[0] !~ RE_DIGIT_DOT_DIGIT  ? shift @{$t}
                   :                                             undef;
    my @extras = (@{$t}, $extra ? @{$extra} : (), @others );


    $self->_fix_generic(
        \$self->[UA_OS], \$self->[UA_NAME], \$self->[UA_VERSION_RAW], \@extras
    );

    $self->[UA_EXTRAS]      = [ @extras ] if @extras;
    $self->[UA_GENERIC]     = 1;
    $self->[UA_PARSER]      = 'generic_moz_thing';

    return 1;
}

sub _generic_name_version {
    my($self, $moz, $thing, $extra, $compatible, @others) = @_;
    my $ok = $moz && ! @{$thing} && ! $extra && ! $compatible && ! @others;
    return if not $ok;

    my @moz = split RE_WHITESPACE, $moz;
    if ( @moz == 1 ) {
        my($name, $version) = split RE_SLASH, $moz;
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
    my($self, $moz, $thing, $extra, $compatible, @others) = @_;
    my @orig_thing = @{ $thing }; # see edge case below

    return if ! ( $compatible && @{$thing} );

    my($mname, $mversion) = split RE_CHAR_SLASH_WS, $moz;
    my($name, $version)   = $mname eq 'Mozilla'
                          ? split( RE_CHAR_SLASH_WS, shift @{ $thing } )
                          : ($mname, $mversion)
                          ;
    shift @{$thing} if  $thing->[0] &&
                      ( $thing->[0] eq $name || $thing->[0] eq $moz);
    my $os     = shift @{$thing};
    my $lang   = pop   @{$thing};
    my @extras;

    if ( $name eq 'MSIE') {
        if ( $self->_is_generic_bogus_ie( $extra ) ) {
            # edge case
            my($n, $v) = split RE_WHITESPACE, shift @orig_thing;
            my $e = [ split RE_SC_WS, join q{ }, @{ $extra } ];
            my $t = \@orig_thing;
            push @{ $e }, grep { $_ } map { split RE_SC_WS, $_ } @others;
            $self->_parse_msie( $moz, $thing, $e, $n, $v );
            return 1;
        }
        elsif ( $extra ) { # Sleipnir?
            ($name, $version)   = split RE_SLASH, pop @{$extra};
            my($extras,$dotnet) = $self->_extract_dotnet( $thing, $extra );
            $self->[UA_DOTNET]  = [ @{$dotnet} ] if @{$dotnet};
            @extras = (@{ $extras }, @others);
        }
        else {
            return if index($moz, q{ }) != NO_IMATCH; # WebTV
        }
    }

    @extras = (@{$thing}, $extra ? @{$extra} : (), @others ) if ! @extras;

    $self->_fix_generic( \$os, \$name, \$version, \@extras );

    $self->[UA_NAME]        = $name;
    $self->[UA_VERSION_RAW] = $version || 0;
    $self->[UA_OS]          = $os;
    $self->[UA_LANG]        = $lang;
    $self->[UA_EXTRAS]      = [ @extras ] if @extras;
    $self->[UA_GENERIC]     = 1;
    $self->[UA_PARSER]      = 'generic_compatible';

    return 1;
}

sub _parse_docomo {
    my($self, $moz, $thing, $extra, $compatible, @others) = @_;
    if ( $thing->[0] && index(lc $thing->[0], 'googlebot-mobile') != NO_IMATCH ) {
        my($name, $version) = split RE_SLASH, shift @{ $thing };
        $self->[UA_NAME]        = $name;
        $self->[UA_VERSION_RAW] = $version;
        $self->[UA_EXTRAS]      = [ @{ $thing } ];
        $self->[UA_MOBILE]      = 1;
        $self->[UA_ROBOT]       = 1;
        $self->[UA_PARSER]      = 'docomo';
        return 1;
    }
    #$self->[UA_PARSER] = 'docomo';
    #require Data::Dumper;warn "DoCoMo unsupported: ".Data::Dumper::Dumper( [ $moz, $thing, $extra, $compatible, \@others ] );
    return;
}

1;

__END__

=pod

=head1 NAME

Parse::HTTP::UserAgent::Base::Parsers - Base class

=head1 DESCRIPTION

Internal module.

=head1 SEE ALSO

L<Parse::HTTP::UserAgent>.

=cut
