package Parse::HTTP::UserAgent::Base::Dumper;
use strict;
use vars qw( $VERSION );
use Parse::HTTP::UserAgent::Constants qw(:all);
use Carp qw( croak );

$VERSION = '0.10';

sub dumper {
    my $self = shift;
    my %opt  = @_ % 2 ? () : (@_);
    %opt = (
        type      => 'dumper',
        format    => 'none',
        interpret => 0,
        %opt
    );
    my $meth = '_dumper_' . lc($opt{type});
    croak "Don't know how to dump with $opt{type}" if ! $self->can( $meth );
    my $buf = $self->$meth( \%opt );
    return $buf if defined wantarray;
    print $buf ."\n";
}

sub _dump_to_struct {
    my %struct    = shift->as_hash;
    $struct{$_} ||= [] for qw( dotnet mozilla extras tk );
    $struct{$_} ||= 0  for qw( unknown );
    return \%struct;
}

sub _dumper_json {
    my $self = shift;
    my $opt  = shift;
    require JSON;
    return  JSON::to_json(
                $self->_dump_to_struct,
                { pretty => $opt->{format} eq 'pretty' }
            );
}

sub _dumper_xml {
    my $self = shift;
    my $opt  = shift;
    require XML::Simple;
    return  XML::Simple::XMLout(
        $self->_dump_to_struct,
        RootName => 'ua',
        NoIndent => $opt->{format} ne 'pretty',
    );
}

sub _dumper_yaml {
    my $self = shift;
    my $opt  = shift;
    require YAML;
    return  YAML::Dump( $self->_dump_to_struct );
}

sub _dumper_dumper {
    my $self = shift;
    my $opt  = shift;
    my @ids  = $opt->{args} ?  @{ $opt->{args} } : $self->_object_ids;
    my $args = $opt->{args} ?                  1 : 0;
    my $max  = 0;
    map { my $l = length $_; $max = $l if $l > $max; } @ids;
    my @titles = qw( FIELD VALUE );
    my $buf    = sprintf "%s%s%s\n%s%s%s\n",
                        $titles[0],
                        (' ' x (2 + $max - length $titles[0])),
                        $titles[1],
                        '-' x $max, ' ' x 2, '-' x ($max*2);
    require Data::Dumper;
    foreach my $id ( @ids ) {
        my $name = $args ? $id->{name} : $id;
        my $val  = $args ? $id->{value} : $self->[ $self->$id() ];
        $val = do {
                    my $d = Data::Dumper->new([$val]);
                    $d->Indent(0);
                    my $rv = $d->Dump;
                    $rv =~ s{ \$VAR1 \s+ = \s+ }{}xms;
                    $rv =~ s{ ; }{}xms;
                    $rv eq '[]' ? '' : $rv;
                } if $val && ref $val;
        $buf .= sprintf "%s%s%s\n",
                        $name,
                        (' ' x (2 + $max - length $name)),
                        defined $val ? $val : ''
                        ;
    }
    return $buf;
}

1;

__END__

=pod

=head1 NAME

Parse::HTTP::UserAgent::Dumper - Base class to dump parsed structure

=head1 DESCRIPTION

The parsed structure can be dumped to a text table for debugging.

=head1 METHODS

=head2 dumper

    my $ua = Parse::HTTP::UserAgent::Dumper->new( $string );
    print $ua->dumper;

=head1 SEE ALSO

L<Parse::HTTP::UserAgent>.

=cut
