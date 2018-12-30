#!/usr/bin/env perl
use strict;
use warnings;

use Capture::Tiny ':all';
use File::Find::Rule;
use GraphViz2;

my $path = shift || die "Usage: perl $0 /some/path [pattern]\n";
my $pattern = shift;

my @files = File::Find::Rule->file()->name('*.pm')->in($path);

# Convert path filenames to modules
my %modules;
for my $file ( @files ) {
    (my $module = $file ) =~ s/^.+?\/lib\/([\w\/]+)\.pm/$1/;
    $module =~ s/\//::/g;

    # Skip if there is a pattern and we don't match it
    next if $pattern && $module !~ /$pattern/;

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
#use Data::Dumper;warn(__PACKAGE__,' ',__LINE__," MARK: ",Dumper\%dependencies);

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
    $g->add_node( name => $module )
        unless $nodes{$module}++;

    # Add any edges
    for my $dep ( @{ $dependencies{$module} } ) {
        $g->add_edge( from => $module, to => $dep )
            unless $edges{ $module . ' ' . $dep }++;
    }
}

# Output a PNG
$g->run( format => 'png', output_file => 'mutual-deps.png' );
