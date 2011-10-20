use strict;
use warnings;
use vars qw( $SILENT );
use IO::File;
use File::Spec;
use File::Basename;
use constant RE_SEPTOR => qr{ \Q[AGENT]\E }xms;
use Test::More;
use Carp       qw( croak );
use File::Find qw( find  );

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
    my $tests = merge_files();
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

sub merge_files {
    my $base = 't/data';
    local *DIR;
    opendir DIR, $base or die "Can't opendir($base): $!";
    my %base_file;
    while ( my $file = readdir DIR ) {
        my $exact = join q{/}, $base, $file;
        next if $file eq '.' || $file eq '..' || -d $exact;
        $base_file{ $exact } = 1;
    }
    closedir DIR;
    my @files;
    my $probe = sub {
        return if -d;
        return if basename( $_ ) =~ m{ \A [.] }xms;
        return if $base_file{ $_ };
        push @files, $_;
    };
    find {
        no_chdir => 1,
        wanted   => $probe,
    }, $base;

    my $raw = q{};
    foreach my $file ( @files ) {
        $raw .= qq{\n\n# Adding $file\n\n} . slurp( $file );
    }

    return $raw;

}

sub thaw {
    my $s = shift || die "Frozen?\n";
    my %rv;
    my $eok = eval "\%rv = (\n $s \n);";
    die "Can not restore data: $@\n\t>> $s <<" if $@ || ! $eok;
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
    my $file = shift;
    my $FH = IO::File->new;
    $FH->open( $file, 'r')
        or croak sprintf 'Can not open DB @ %s: %s', $file, $!;
    my $rv = do { local $/; my $s = <$FH>; $s };
    $FH->close;
    return $rv;
}

1;

__END__
