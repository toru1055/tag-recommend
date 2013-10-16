#!/usr/bin/perl
use strict;

use IO::File;
use Text::CSV_XS;
use Encode;

my $fh = IO::File->new('Train.csv') or die 'cannot open file';
my $fhval = IO::File->new("> Validate.csv") or die 'cannot open file';
my $csv = Text::CSV_XS->new({binary => 1, always_quote => 1});

my $data_start = $ARGV[0];
my $data_num = $ARGV[1];
my $i = 0;
print $fhval '"id","Title","Body","Tags"',"\n";
until ($fh->eof) {
  my $columns = $csv->getline($fh);
  $i = $i + 1;
  if($i-1 > $data_start && $i-1 <= $data_start+$data_num) {
    my $id    = $columns->[0];
    my $title = encode('utf-8', $columns->[1]);
    my $body  = encode('utf-8', $columns->[2]);
    my $answer_tags = $columns->[3];
    print $fhval '"',$id,'",';
    print $fhval '"',$title,'",';
    print $fhval '"',$body,'",';
    print $fhval '"',$answer_tags,'"';

    #my $status = $csv->print($fhval, $columns);
    print $fhval "\n";
  } elsif($i-1 > $data_start+$data_num) {
    last;
  }
}
$fh->close;
$fhval->close;
