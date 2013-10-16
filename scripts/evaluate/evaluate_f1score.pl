#!/usr/bin/perl
use strict;
use Data::Dumper;

my $tp = 0;
my $fp = 0;
my $fn = 0;

while(<STDIN>) {
  chomp $_;
  next if($_ =~ /Tag/);
  my ($id,$pred_tags,$answer_tags) = split(/,/, $_);
  my @pred_tags_array = split(/\s/, $pred_tags);
  my @answer_tags_array = split(/\s/, $answer_tags);
  my %pred_tags_hash = {};
  my %answer_tags_hash = {};

  foreach my $tag (@pred_tags_array) {
    $pred_tags_hash{$tag} = 1;
  }
  foreach my $tag (@answer_tags_array) {
    $answer_tags_hash{$tag} = 1;
    if(!exists $pred_tags_hash{$tag}) {
      $fn += 1;
    }
  }
  foreach my $tag (@pred_tags_array) {
    if(exists $answer_tags_hash{$tag}) {
      $tp += 1;
    } else {
      $fp += 1;
    }
  }
}
print "tp=$tp, fp=$fp, fn=$fn\n";
my $precision = $tp / ($tp + $fp);
my $recall = $tp / ($tp + $fn);
my $f1_score = (2 * $precision * $recall) / ($precision + $recall);
print "precision=$precision, recall=$recall","\n";
print "F1-Score: ",$f1_score, "\n";
