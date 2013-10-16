#!/usr/bin/perl
use strict;
use IO::File;
use Text::CSV_XS;
use Data::Dumper;
use Text::Ngram qw(ngram_counts add_to_counts);
use Encode;

my $fh = IO::File->new('Train.csv') or die 'cannot open file';
my $csv = Text::CSV_XS->new({binary => 1});

my $data_num = $ARGV[0];
my $i = 0;
my $df = {};

until ($fh->eof) {
  if($i > $data_num){ last; }
  my $columns = $csv->getline($fh);
  if($i++ == 0){ next; }
  my $title = $columns->[1];
  my $body  = $columns->[2];
  my $text = "$title $body";
  $text = encode('utf-8', $text);
  my $ngrams = ngram_counts($text, 3);
  foreach my $t (keys %{$ngrams}) {
    if(exists $df->{$t}) {
      $df->{$t} += 1;
    } else {
      $df->{$t}  = 1;
    }
  }
}
$fh->close;

foreach my $t (sort{ $df->{$b} <=> $df->{$a} } keys %{$df}) {
  print $t,"\t",log($data_num / $df->{$t}),"\n";
}
