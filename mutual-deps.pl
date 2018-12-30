#!/usr/bin/env perl
use strict;
use warnings;

use File::Find::Rule;
use Capture::Tiny ':all';

my $path = shift || die "Usage: perl $0 /some/path\n";

my @files = File::Find::Rule->file()->name('*.pm')->in($path);

# Convert path filenames to modules
my %modules;
for my $file ( @files ) {
    (my $module = $file ) =~ s/^.+?\/lib\/([\w\/]+)\.pm/$1/;
    $module =~ s/\//::/g;
    $modules{$module} = $file;
}

my %dependencies;

for my $module ( keys %modules ) {
    # Get the module dependencies
    my ($stdout, $stderr, $exit) = capture {
        system( 'scandeps.pl', '-R', $modules{$module} );
    };

    # Parse the dependencies from the system output
    my @deps;
    my @parts = split /\s*,\s*/, $stdout;
    for my $part ( @parts ) {
        my @strings = split /\s*=>\s*/, $part;
        push @deps, $strings[0];
    }

    # Tally the module dependencies
    $dependencies{$module} = \@deps;
}
use Data::Dumper;warn(__PACKAGE__,' ',__LINE__," MARK: ",Dumper\%dependencies);
