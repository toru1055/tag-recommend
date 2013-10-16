#!/usr/bin/perl
use strict;
use IO::File;
use Text::CSV_XS;
use Data::Dumper;
use Text::Ngram qw(ngram_counts add_to_counts);
use Encode;

my $MAX_TAG_NGRAM_NUM = 300;

my $data_num = $ARGV[0];
my $section = $ARGV[1];
my $fh = IO::File->new('Train.csv') or die 'cannot open file';
my $csv = Text::CSV_XS->new({binary => 1});
my $i = 0;
my $idf = read_kv("mid_data/idf_dict.txt");
my $m;
my $tag_ngnum = {};

until ($fh->eof) {
  if($i > $data_num){ last; }
  print STDERR "exec counter: $i\n" if($i % 10000 == 0);

  my $columns = $csv->getline($fh);
  if($i++ == 0){ next; }
  my $title = $columns->[1];
  my $body  = $columns->[2];
  my $doc_hash = {'title'=>$title, 'body'=>$body};
  my @tags  = split(/\s/, $columns->[3]);
  #my $doc = $title; #"$title $body";
  my $doc = $doc_hash->{$section};
  $doc = encode('utf-8', $doc);
  my $ngs_doc = ngram_counts($doc, 3);
  foreach my $tag (@tags) {
    foreach my $ng (keys %{$ngs_doc}) {
      if(exists $m->{$tag}->{$ng}) {
        $m->{$tag}->{$ng} += $ngs_doc->{$ng} * get_idf($ng);
      } else {
        $m->{$tag}->{$ng}  = $ngs_doc->{$ng} * get_idf($ng);
      }
      if(exists $tag_ngnum->{$tag}) {
        $tag_ngnum->{$tag} += $ngs_doc->{$ng};
      } else {
        $tag_ngnum->{$tag}  = $ngs_doc->{$ng};
      }
    }
  }
}
$fh->close;

foreach my $tag (sort keys %{$m}) {
  if($tag_ngnum->{$tag} != 0) {
    my $ng_num = 0;
    foreach my $ng (sort{ $m->{$tag}->{$b} <=> $m->{$tag}->{$a} } keys %{$m->{$tag}}) {
      if($ng_num++ > $MAX_TAG_NGRAM_NUM){ last; }
      if(exists $m->{$tag}->{$ng}) {
        my $tfidf = $m->{$tag}->{$ng} / $tag_ngnum->{$tag};
        print $tag,"\t",$ng,"\t",$tfidf,"\n";
      }
    }
  }
}

sub get_idf {
  my ($ng) = @_;
  if(exists $idf->{$ng}) {
    return $idf->{$ng}
  } else {
    return log(1000000.0 / 1.0);
  }
}

sub read_kv {
  my ($filename) = @_;
  my $kv = {};
  open(FH, $filename);
  while(<FH>) {
    chomp $_;
    my ($k,$v) = split(/\t/,$_);
    if(exists $kv->{$k}) {
      $kv->{$k} += $v;
    } else {
      $kv->{$k}  = $v;
    }
  }
  return $kv;
}
