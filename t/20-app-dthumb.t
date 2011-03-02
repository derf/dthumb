#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use Test::More tests => 2;

use_ok('App::Dthumb');

my $dthumb = App::Dthumb->new();

isa_ok($dthumb, 'App::Dthumb');
