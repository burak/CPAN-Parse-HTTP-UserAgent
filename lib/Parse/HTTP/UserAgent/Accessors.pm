package Parse::HTTP::UserAgent::Accessors;
use strict;
use vars qw( $VERSION );
use Parse::HTTP::UserAgent::Constants qw(:all);

$VERSION = '0.11';

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
    return +() if ! $self->[UA_TOOLKIT];
    return @{ $self->[UA_TOOLKIT] };
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

1;

__END__

=pod

=head1 NAME

Parse::HTTP::UserAgent::Accessors - Available accessors

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

=head3 robot

=head3 toolkit

=head3 unknown

=head3 version

=head1 SEE ALSO

L<Parse::HTTP::UserAgent>.

=cut
