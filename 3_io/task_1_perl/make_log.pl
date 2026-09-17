#!/usr/bin/perl
use strict;
use warnings;

my $path = shift || 'access.log';
my $count = shift || 20000;

my @ips = map { "192.168.1." . $_ } (10 .. 40);
push @ips, "10.0.0.5", "10.0.0.6", "172.16.4.1";

my @urls = (
    '/', '/index.html', '/about', '/api/users', '/api/orders',
    '/static/style.css', '/static/app.js', '/images/logo.png',
    '/login', '/logout', '/admin', '/search?q=test',
);

my @codes = (200) x 70;
push @codes, (304) x 8, (301) x 4, (404) x 10, (403) x 3, (500) x 4, (503) x 1;

my @methods = ('GET') x 8;
push @methods, 'POST', 'POST', 'HEAD';

my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

srand(42);
open(my $out, '>', $path) or die "не создаётся $path: $!\n";

my $time = 0;
for my $i (1 .. $count) {
    if ($i % 97 == 0) {
        print $out "битая строка без формата\n";
        next;
    }

    $time += int(rand(5));
    my @t = gmtime(1772582400 + $time);
    my $stamp = sprintf("%02d/%s/%04d:%02d:%02d:%02d +0300",
        $t[3], $months[$t[4]], $t[5] + 1900, $t[2], $t[1], $t[0]);

    my $ip = $ips[int(scalar(@ips) * (rand() ** 2))];
    my $url = $urls[int(scalar(@urls) * (rand() ** 2))];
    my $code = $codes[int(rand(scalar @codes))];
    my $method = $methods[int(rand(scalar @methods))];
    my $size = $code == 200 ? int(rand(20000)) + 200 : ($code == 304 ? '-' : int(rand(800)));

    print $out "$ip - - [$stamp] \"$method $url HTTP/1.1\" $code $size\n";
}
close($out);

print "Готово: $count строк в $path\n";
