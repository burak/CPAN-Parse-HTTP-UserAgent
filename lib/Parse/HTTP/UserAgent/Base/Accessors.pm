package Parse::HTTP::UserAgent::Base::Accessors;
use strict;
use vars qw( $VERSION );
use Parse::HTTP::UserAgent::Constants qw(:all);

$VERSION = '0.11';

#TODO: new accessors
#wap
#mobile
#device

sub name             { shift->[UA_NAME]             || '' }
sub unknown          { shift->[UA_UNKNOWN]          || '' }
sub generic          { shift->[UA_GENERIC]          || '' }
sub os               { shift->[UA_OS]               || '' }
sub lang             { shift->[UA_LANG]             || '' }
sub strength         { shift->[UA_STRENGTH]         || '' }
sub parser           { shift->[UA_PARSER]           || '' }
sub original_name    { shift->[UA_ORIGINAL_NAME]    || '' }
sub original_version { shift->[UA_ORIGINAL_VERSION] || '' }
sub robot            { shift->[UA_ROBOT]            || 0  }

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

1;

__END__

=pod

=head1 NAME

Parse::HTTP::UserAgent::Base::Accessors - Available accessors

=head1 SYNOPSIS

   use Parse::HTTP::UserAgent;
   my $ua = Parse::HTTP::UserAgent->new( $str );
   die "Unable to parse!" if $ua->unknown;
   print $ua->name;
   print $ua->version;
   print $ua->os;

=head1 DESCRIPTION

Ther methods can be used to access the various parts of the parsed structure.

=head1 ACCESSORS

The parts of the parsed structure can be accessed using these methods:

=head2 dotnet

=head2 extras

=head2 generic

=head2 lang

=head2 mozilla

=head2 name

=head2 original_name

=head2 original_version

=head2 os

=head2 parser

=head2 robot

=head2 strength

=head2 toolkit

=head2 unknown

=head2 version

=head1 SEE ALSO

L<Parse::HTTP::UserAgent>.

=cut
