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

1;

__END__
