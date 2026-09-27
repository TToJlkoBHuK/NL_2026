#!/usr/bin/perl
use strict;
use warnings;

my ($log_path, $report_path) = @ARGV;
unless (defined $log_path && defined $report_path) {
    die "Использование: perl loganalyzer.pl <файл журнала> <файл отчёта>\n";
}

open(my $log, '<', $log_path) or die "не открывается $log_path: $!\n";

print "Фильтр по первой цифре кода ответа (4, 5, ...), пусто - без фильтра: ";
my $filter = <STDIN>;
$filter = defined $filter ? $filter : '';
$filter =~ s/^\s+|\s+$//g;

my $line_re = qr/^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+)[^"]*" (\d{3}) (\d+|-)/;

my ($total, $matched, $broken, $bytes) = (0, 0, 0, 0);
my (%by_code, %by_ip, %by_url);
my @bad_lines;

while (my $line = <$log>) {
    chomp $line;
    next if $line =~ /^\s*$/;
    $total++;

    my ($ip, $stamp, $method, $url, $code, $size) = $line =~ $line_re;
    unless (defined $code) {
        $broken++;
        push @bad_lines, "$.: $line" if @bad_lines < 50;
        next;
    }

    next if $filter ne '' && substr($code, 0, 1) ne $filter;

    $matched++;
    $by_code{$code}++;
    $by_ip{$ip}++;
    $by_url{$url}++;
    $bytes += $size if $size ne '-';
}
close($log);

sub top {
    my ($table, $count) = @_;
    my @keys = sort { $table->{$b} <=> $table->{$a} || $a cmp $b } keys %$table;
    return @keys[0 .. ($count - 1 > $#keys ? $#keys : $count - 1)];
}

sub human {
    my $n = shift;
    return sprintf("%.2f МБ", $n / 1048576) if $n >= 1048576;
    return sprintf("%.2f КБ", $n / 1024) if $n >= 1024;
    return "$n Б";
}

open(my $report, '>', $report_path) or die "не создаётся $report_path: $!\n";

print $report "Отчёт по журналу $log_path\n";
print $report "Фильтр: " . ($filter eq '' ? "нет" : "коды ${filter}xx") . "\n\n";
print $report "Всего строк:      $total\n";
print $report "Прошло фильтр:    $matched\n";
print $report "Не разобрано:     $broken\n";
print $report "Объём трафика:    " . human($bytes) . "\n\n";

print $report "Коды ответа:\n";
for my $code (sort keys %by_code) {
    printf $report "  %-5s %6d\n", $code, $by_code{$code};
}

print $report "\nДесять самых активных адресов:\n";
for my $ip (top(\%by_ip, 10)) {
    printf $report "  %-16s %6d\n", $ip, $by_ip{$ip};
}

print $report "\nДесять самых запрашиваемых адресов:\n";
for my $url (top(\%by_url, 10)) {
    printf $report "  %-28s %6d\n", $url, $by_url{$url};
}

if (@bad_lines) {
    print $report "\nНеразобранные строки:\n";
    print $report "  $_\n" for @bad_lines;
}

close($report);

print "\n";
print "Всего строк:   $total\n";
print "Прошло фильтр: $matched\n";
print "Не разобрано:  $broken\n";
print "Трафик:        " . human($bytes) . "\n";
print "Коды: " . join(", ", map { "$_=$by_code{$_}" } sort keys %by_code) . "\n";
print "Подробный отчёт записан в $report_path\n";
