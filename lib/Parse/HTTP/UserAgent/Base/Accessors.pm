package Parse::HTTP::UserAgent::Base::Accessors;
use strict;
use warnings;
use vars qw( $VERSION );
use Parse::HTTP::UserAgent::Constants qw(:all);

$VERSION = '0.11';

#TODO: new accessors
#wap
#mobile
#device

BEGIN {
    my @simple = qw(
        name
        unknown
        generic
        os
        lang
        strength
        parser
        original_name
        original_version
        robot
    );

    my @multi = qw(
        mozilla
        toolkit
        extras
        dotnet
    );

    ## no critic (TestingAndDebugging::ProhibitNoStrict)
    no strict qw(refs);
    foreach my $name ( @simple ) {
        my $id = 'UA_' . uc $name;
        $id = __PACKAGE__->$id();
        *{ $name } = sub { return shift->[$id] || q{} };
    }

    foreach my $name ( @multi ) {
        my $id = 'UA_' . uc $name;
        $id = __PACKAGE__->$id();
        *{ $name } = sub {
            my $self = shift;
            return +() if ! $self->[ $id ];
            my @rv = @{ $self->[ $id ] };
            return wantarray ? @rv : $rv[0];
        };
    }
}

sub version {
    my $self = shift;
    my $type = shift || q{};
    return $self->[ $type eq 'raw' ? UA_VERSION_RAW : UA_VERSION ] || 0;
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
