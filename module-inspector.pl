#!/usr/bin/env perl

use Mojolicious::Lite -signatures;

use Data::Dumper;
use Data::Dumper::Compact qw(ddc);
use Package::Stash ();
use Sub::Identify qw(stash_name);
use Text::Trim qw(trim);

get '/' => sub ($c) {
    my $module = $c->param('module') || 'GD';

    my $subs = gather_subs($module);

    $c->render(
        template => 'index',
        module => $module,
        subs => Dumper($subs),
    );
};

sub gather_subs {
    my ($module) = @_;

    eval "require $module";
    if ($@) {
        die "Can't require $module: $@\n";
    }
 
    my $subs = Package::Stash->new($module)->get_all_symbols('CODE');
 
    my %subs;

    for my $sub (sort keys %$subs) {
        my $packagename = stash_name($subs->{$sub});
        if ($packagename eq $module) {
            my $code = ddc($subs->{$sub});
            while ($code =~ /^(.*)\n/mg) {
                my $line = trim $1;
                push @{ $subs{$sub} }, $line
                    if $line =~ /=\s*\@_/ || $line =~ /=\s*shift/;
            }
        }
    }

    return \%subs;
}

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Package Inspector';
<h1>Package Inspector</h1>
<form>
<input type="text" name="module" value="<%= $module %>"/>
<input type="submit" name="submit" value="Submit"/>
</form>
<pre><%= $subs %></pre>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
