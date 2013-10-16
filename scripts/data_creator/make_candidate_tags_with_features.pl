#!/usr/bin/perl
use strict;
use IO::File;
use Text::CSV_XS;
use Data::Dumper;
use Text::Ngram qw(ngram_counts add_to_counts);
use Encode;

my $MAX_CLUSTER_NUM = 3;
my $MAX_TAG_CANDIDATE_BY_RANK = 300;
my $MAX_TAG_NGRAM_NUMS = 60;

my $data_start = $ARGV[0];
my $data_num = $ARGV[1];
my $fh = IO::File->new('Train.csv') or die 'cannot open file';
my $csv = Text::CSV_XS->new({binary => 1});
my $idf = read_kv("mid_data/idf_dict.txt");
my $m = read_kkv("mid_data/tag_ngram_title.txt"); # tag_features of title
my $btm = read_kkv("mid_data/tag_ngram_body.txt"); # filename will be changed. tag_features of body.
my $cm = read_kkv("mid_data/cluster_with_features.txt"); # cluster_features of title
my $cluster_tags = read_kv("mid_data/cluster_with_tags.txt");
my $tag_weights = read_kv("mid_data/tag_weights.txt");
my $top_weighted_tags = {};

my $j_idx = 0;
foreach my $tag (sort{$tag_weights->{$b}<=>$tag_weights->{$a}} %{$tag_weights}) {
  if ($j_idx++ < $MAX_TAG_CANDIDATE_BY_RANK) {
    $top_weighted_tags->{$tag} = 1;
  }
}

foreach my $cluster (keys %{$cm}) {
  normalize_vector($cm->{$cluster});
}
foreach my $tag (keys %{$m}) {
  normalize_vector($m->{$tag});
}
foreach my $tag (keys %{$btm}) {
  normalize_vector($btm->{$tag});
}

# TODO Normalizeとかは事前にしておく
print join("\t", ('label','title_cosine','body_cosine','title_body_cosine','body_title_cosine','tag_weight_zero_cosine', 'tag_weight_nonzero_cosine')),"\n";
my $i = 0;
until ($fh->eof) {
  my $columns = $csv->getline($fh);
  $i++;
  if($i-1 >  $data_start+$data_num){ last; }
  if($i-1 <= $data_start){ next; }
  print STDERR $i,"\n" if($i % 100 == 0);
  my $id    = $columns->[0];
  my $title = encode('utf-8', $columns->[1]);
  my $body  = encode('utf-8', $columns->[2]);
  my @tags  = split(/\s/, $columns->[3]);
  my $tags_hash = {};
  foreach my $tag (@tags) {
    $tags_hash->{$tag} = 1;
  }

  my $title_tfidf = get_tfidf_hash(ngram_counts($title, 3));
  my $body_tfidf  = get_tfidf_hash(ngram_counts($body, 3));
  normalize_vector($title_tfidf);
  normalize_vector($body_tfidf);

  my $cluster_scores = {};
  foreach my $cluster (keys %{$cm}) {
    $cluster_scores->{$cluster} = get_cosine_similarity($title_tfidf, $cm->{$cluster});
  }
  my $candidate_tags = {};
  my $j;

#  $j = 0;
#  foreach my $cluster (sort{$cluster_scores->{$b}<=>$cluster_scores->{$a}} %{$cluster_scores}) {
#    if($j++ < $MAX_CLUSTER_NUM) {
#      my @c_tags = split(/,/, $cluster_tags->{$cluster});
#      foreach my $tag (@c_tags) {
#        $candidate_tags->{$tag} = 1;
#      }
#    }
#  }
  foreach my $tag (keys %{$top_weighted_tags}) {
    $candidate_tags->{$tag} = 1;
  }
  print STDERR scalar(keys %{$candidate_tags}),"\n" if($i % 100 == 0);

  my @candidate_tags_with_features = ();
  foreach my $tag (keys %{$candidate_tags}) {
    my $tag_with_features = {};
    if(exists $tags_hash->{$tag}) {
      $tag_with_features->{'label'} = "+1";
    } else {
      next if(rand(300) > 1);
      $tag_with_features->{'label'} = "-1";
    }
    $tag_with_features->{'title_cosine'} = get_cosine_similarity($title_tfidf, $m->{$tag});
    $tag_with_features->{'body_cosine'} = get_cosine_similarity($body_tfidf, $btm->{$tag});
    $tag_with_features->{'title_body_cosine'} = get_cosine_similarity($title_tfidf, $btm->{$tag});
    $tag_with_features->{'body_title_cosine'} = get_cosine_similarity($body_tfidf, $m->{$tag});
    #if($tag_with_features->{'title_cosine'}==0 && $tag_with_features->{'body_cosine'}==0) {
    if($tag_with_features->{'title_cosine'}==0) {
      $tag_with_features->{'tag_weight_zero_cosine'} = log($tag_weights->{$tag});
      $tag_with_features->{'tag_weight_nonzero_cosine'} = 0.0;
    } else {
      $tag_with_features->{'tag_weight_zero_cosine'} = 0.0;
      $tag_with_features->{'tag_weight_nonzero_cosine'} = log($tag_weights->{$tag});
    }
    $tag_with_features->{'tag_weight'} = log($tag_weights->{$tag});
    $tag_with_features->{'tag_name'} = $tag;
    push(@candidate_tags_with_features, $tag_with_features);
  }

  foreach my $tag_with_features (@candidate_tags_with_features) {
    print $tag_with_features->{'label'};
    print "\t",$tag_with_features->{'title_cosine'};
    print "\t",$tag_with_features->{'body_cosine'};
    print "\t",$tag_with_features->{'title_body_cosine'};
    print "\t",$tag_with_features->{'body_title_cosine'};
    print "\t",$tag_with_features->{'tag_weight_zero_cosine'};
    print "\t",$tag_with_features->{'tag_weight_nonzero_cosine'};
    #print "\t",$tag_with_features->{'tag_name'};
    #print "\t",$tag_with_features->{'tag_weight'};
    print "\n";
  }
}
$fh->close;

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

# input vector should be normalized.
sub get_cosine_similarity {
  my ($a, $b) = @_;
  my $dot_product = 0.0;
  foreach my $ng (keys %{$a}) {
    if(exists $b->{$ng}) {
      $dot_product += $a->{$ng} * $b->{$ng};
    }
  }
  return $dot_product;
}

sub get_tfidf_hash {
  my ($ngrams) = @_;
  my $tfidfs;
  my $ngnum = 0;
  foreach my $ng (keys %{$ngrams}) {
    $ngnum += $ngrams->{$ng};
    $tfidfs->{$ng} = $ngrams->{$ng} * get_idf($ng);
  }
  my $result = {};
  if($ngnum != 0) {
    my $i = 0;
    foreach my $ng (sort{$tfidfs->{$b} <=> $tfidfs->{$a}} %{$tfidfs}) {
      if($i++ < $MAX_TAG_NGRAM_NUMS) {
        $result->{$ng} = $tfidfs->{$ng} / $ngnum;
      }
    }
    return $result;
  } else {
    return {};
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
  return $kv;
}
