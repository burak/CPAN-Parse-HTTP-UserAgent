use strict;
use warnings;
use vars qw( $SILENT );
use IO::File;
use File::Spec;
use constant DATABASE  => File::Spec->catfile(qw( t data parse.dat ));
use constant RE_SEPTOR => qr{ \Q[AGENT]\E }xms;
use Test::More;
use Carp qw(croak);

my @todo;

END {
    if ( @todo && ! $SILENT ) {
        diag( 'Tests marked as TODO are listed below' );
        diag("'$_'") for @todo;
    }
}

sub database {
    my $opt = shift || {};
    my @buf;
    my $tests = trim( slurp() );
    my $id    = 0;
    foreach my $test ( split RE_SEPTOR, $tests ) {
        next if ! $test;
        my $raw = trim( strip_comments( $test ) ) || next;
        my($string, $frozen) = split m{ \n }xms, $raw, 2;
        push @buf, {
            string => $string,
            struct => $frozen && $opt->{thaw} ? { thaw( $frozen ) } : $frozen,
            id     => ++$id,
        };
    }
    return @buf;
}

sub thaw {
    my $s = shift || die "Frozen?\n";
    my %rv;
    my $eok = eval "\%rv = (\n $s \n);";
    die "Can not restore data: $@\n" if $@ || ! $eok;
    return %rv;
}

sub trim {
    my $s = shift;
    return $s if ! $s;
    $s =~ s{ \A \s+    }{}xms;
    $s =~ s{    \s+ \z }{}xms;
    return $s;
}

sub strip_comments {
    my $s = shift;
    return $s if ! $s;
    my $buf = q{};
    foreach my $line ( split m{ \n }xms, $s ) {
        chomp $line;
        next if ! $line;
        if ( my @m = $line =~ m{ \A [#] (.+?) \z }xms ) {
            if ( my @n = $m[0] =~ m{ \A TODO: \s? (.+?) \z }xms ) {
                push @todo, $n[0];
            }
            next;
        }
        $buf .= $line . "\n";
    }
    return $buf;
}

sub slurp {
    my $FH = IO::File->new;
    $FH->open( DATABASE, 'r')
        or croak sprintf 'Can not open DB @ %s: %s', DATABASE, $!;
    my $rv = do { local $/; my $s = <$FH>; $s };
    $FH->close;
    return $rv;
}

1;

__END__
