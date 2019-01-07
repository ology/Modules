#!/usr/bin/env perl
use strict;
use warnings;

# Output the module dependencies in a directory of modules.
#
#  perl mutual-deps.pl /include/path include_pattern show_all csv_exclude_patterns
#
#  * "show_all" means to show all the modules under the path, or *only* those in the include_pattern.
#
# Example:
#  perl mutual-deps.pl /some/path Xyz 1 foo,bar

use Capture::Tiny ':all';
use File::Find::Rule;
use GraphViz2;

my $path     = shift || die "Usage: perl $0 /some/path [pattern] [show-all]\n";
my $pattern  = shift || '';  # Module names to include
my $show_all = shift // 0;
my $exclude  = shift;  # CSV of patterns to exclude

$exclude = [ split /\s*,\s*/, $exclude ]
    if $exclude;

# Gather the important files
my @pmfiles = File::Find::Rule->file()->name('*.pm')->in($path);

# Exclude any given patterns
my @files;
FILE: for my $file ( @pmfiles ) {
    for my $pat ( @$exclude ) {
        next FILE if $file =~ /$pat/;
    }
    push @files, $file;
}

# Convert path filenames to modules
my %modules;
for my $file ( @files ) {
    (my $module = $file ) =~ s/^.+?\/lib\/([\w\/]+)\.pm$/$1/;
    $module =~ s/\//::/g;

    # Skip if there is a pattern and we don't match it
    next if !$show_all && $pattern && $module !~ /$pattern/;

    $modules{$module} = $file;
}

my %dependencies;

# Inspect each module
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
        ( my $dep = $strings[0] ) =~ s/'//g;
        push @deps, $dep;
    }

    # Tally the module dependencies
    $dependencies{$module} = \@deps;
}
#use Data::Dumper; warn Dumper\%dependencies; exit;

# Instantiate a graphviz object
my $g = GraphViz2->new(
    global => { directed => 1 },
    node   => { shape => 'oval' },
    edge   => { color => 'grey' },
);

my %nodes;
my %edges;

# Build the network graph
for my $module ( keys %dependencies ) {
    my $color = $pattern && $module =~ /$pattern/ ? 'blue' : 'black';

    $g->add_node( name => $module, color => $color )
        unless $nodes{$module}++;

    # Add any edges
    for my $dep ( @{ $dependencies{$module} } ) {
        $g->add_edge( from => $module, to => $dep )
            unless $edges{ $module . ' ' . $dep }++;
    }
}

# Output a PNG
$g->run( format => 'png', output_file => 'mutual-deps.png' );
