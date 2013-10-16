#!/usr/bin/perl
use strict;
use Data::Dumper;
use Text::Bayon;

my $MAX_CLUSTER_NGRAM_NUMS = 1000;

my $bayon = Text::Bayon->new;
my $bayon_options = {
  number => 400, 
  method => 'rb',
};

my $m = read_kkv("mid_data/tag_ngram.txt");
my $tag_weights = read_kv("mid_data/tag_weights.txt");
open(FH1, "> mid_data/cluster_with_tags.txt");
open(FH2, "> mid_data/cluster_with_features.txt");

my $cluster_tags = $bayon->clustering($m, $bayon_options);
my $means;
foreach my $cluster (keys %{$cluster_tags}) {
  my $cluster_nums = 0.0;
  print FH1 $cluster,"\t",join(",", @{$cluster_tags->{$cluster}}),"\n";
  foreach my $tag (@{$cluster_tags->{$cluster}}) {
    $cluster_nums = $cluster_nums + 1; # + $tag_weights->{$tag};
    normalize_vector($m->{$tag});
    foreach my $ng (keys %{$m->{$tag}}) {
      if(exists $means->{$cluster}->{$ng}) {
        $means->{$cluster}->{$ng} += $m->{$tag}->{$ng}; # * $tag_weights->{$tag};
      } else {
        $means->{$cluster}->{$ng}  = $m->{$tag}->{$ng}; # * $tag_weights->{$tag};
      }
    }
  }
  my $i = 0;
  foreach my $ng (sort{$means->{$cluster}->{$b} <=> $means->{$cluster}->{$a}} %{$means->{$cluster}}) {
    if($i++ < $MAX_CLUSTER_NGRAM_NUMS) {
      if(exists $means->{$cluster}->{$ng}) {
        my $average = $means->{$cluster}->{$ng} / $cluster_nums;
        print FH2 $cluster,"\t",$ng,"\t",$average,"\n";
      }
    }
  }
}
close(FH1);
close(FH2);

sub normalize_vector {
  my ($vec) = @_;
  my $v_power = 0.0;
  foreach my $t (keys %{$vec}) {
    $v_power += $vec->{$t}*$vec->{$t};
  }
  $v_power = sqrt($v_power);
  my $i = 0;
  foreach my $t (keys %{$vec}) {
    $vec->{$t} = $vec->{$t} / $v_power;
  }
}

sub read_kkv {
  my ($filename) = @_;
  my $kkv;
  open(FH, $filename);
  while(<FH>) {
    chomp $_;
    my ($k1,$k2,$v) = split(/\t/,$_);
    if (exists $kkv->{$k1}->{$k2}) {
      $kkv->{$k1}->{$k2} += $v;
    } else {
      $kkv->{$k1}->{$k2}  = $v;
    }
  }
  close(FH);
  return $kkv;
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
  close(FH);
  return $kv;
}
