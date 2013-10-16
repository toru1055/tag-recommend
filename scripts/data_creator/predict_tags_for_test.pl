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
my $MAX_PREDICTED_TAGS = 10;

my $data_start = $ARGV[0];
my $data_num = $ARGV[1];
my $input_filename = $ARGV[2];
my $fh = IO::File->new($input_filename) or die 'cannot open file';
my $csv = Text::CSV_XS->new({binary => 1});
my $idf = read_kv("mid_data/idf_dict.txt");
my $m = read_kkv("mid_data/tag_ngram.txt"); # tag_features of title
my $btm = read_kkv("mid_data/tag_ngram.txt"); # filename will be changed. tag_features of body.
my $cm = read_kkv("mid_data/cluster_with_features.txt"); # cluster_features of title
my $cluster_tags = read_kv("mid_data/cluster_with_tags.txt");
my $tag_weights = read_kv("mid_data/tag_weights.txt");
my $fc = read_kv("mid_data/feature_center.txt");
my $fs = read_kv("mid_data/feature_scale.txt");
my $fw = read_kv("mid_data/feature_weights.txt");
my $top_weighted_tags = {};

my $j_idx = 0;
foreach my $tag (sort{$tag_weights->{$b}<=>$tag_weights->{$a}} keys %{$tag_weights}) {
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

print '"Id","Tags"',"\n";
my $i = 0;
until ($fh->eof) {
  my $columns = $csv->getline($fh);
  $i++;
  if($i-1 >  $data_start+$data_num){ last; }
  if($i-1 <= $data_start){ next; }
  print STDERR $i,"\n" if($i % 1000 == 0);
  my $id    = $columns->[0];
  my $title = encode('utf-8', $columns->[1]);
  my $body  = encode('utf-8', $columns->[2]);

  my $title_tfidf = get_tfidf_hash(ngram_counts($title, 3));
  my $body_tfidf  = get_tfidf_hash(ngram_counts($body, 3));
  normalize_vector($title_tfidf);
  normalize_vector($body_tfidf);

  # TODO: 1. 愚直に全部予測するのではなく、tag_weightsの高いタグを上位から順番に予測していき、
  # ポジティブなタグが３，４個たまったらそのインスタンスの処理を終えるようにする。
  # tag_weightsの数はもっと増やさないといけない。２０００本で８割のタグを網羅する。
  # クラスタは、上位タグで３，４個埋まらなかった時に利用する：精度を向上させるためのものである。
  # TODO: 2. オフラインでF1-scoreの評価を行えるようにする。
  # TODO: 3. 予測時の状態に合わせるようバイアスを取り除いた、学習データ作成を心がける。
  # TODO: 4. とにかくモデルの精緻化を図る。
  # body用の学習データ作成。
  # ドキュメントの持っているタグ数をバイアス項として学習する。

  my $candidate_tags = {};
  my $j;


#  my $cluster_scores = {};
#  foreach my $cluster (keys %{$cm}) {
#    $cluster_scores->{$cluster} = get_cosine_similarity($title_tfidf, $cm->{$cluster});
#  }
#
#  $j = 0;
#  foreach my $cluster (sort{$cluster_scores->{$b}<=>$cluster_scores->{$a}} keys %{$cluster_scores}) {
#    if($j++ < $MAX_CLUSTER_NUM) {
#      my @c_tags = split(/,/, $cluster_tags->{$cluster});
#      foreach my $tag (@c_tags) {
#        $candidate_tags->{$tag} = 1;
#      }
#    }
#  }

  $j = 0;
  foreach my $tag (keys %{$top_weighted_tags}) {
    $j++;
    my $p_score = predict_tag_score($tag, $title_tfidf, $body_tfidf);
    if($p_score > 0.0) {
      #if(scalar(keys %{$candidate_tags}) > $MAX_PREDICTED_TAGS) { last; }
      $candidate_tags->{$tag} = 1;
    }
  }

  #print STDERR scalar(keys %{$candidate_tags}),"\n" if($i % 1000 == 0);
  print STDERR "exec num: $j\n" if($i % 100 == 0);

  my $predicted_tags_with_score = {};
  foreach my $tag (keys %{$candidate_tags}) {
    #my $p_score = predict_tag_score($tag, $title_tfidf, $body_tfidf);
    #if($p_score > 1.0) {
      #$predicted_tags_with_score->{$tag} = $p_score;
      $predicted_tags_with_score->{$tag} = 1.0;
      #}
  }

  $j = 0;
  my @predicted_tags = ();
  foreach my $tag (sort{$predicted_tags_with_score->{$b}<=>$predicted_tags_with_score->{$a}} keys %{$predicted_tags_with_score}) {
    #if($j++ < $MAX_PREDICTED_TAGS) {
      push(@predicted_tags, $tag);
      #}
  }

  my $answer_tags = $columns->[3];
  my $predicted_tags_str = join(" ", @predicted_tags);
  if($answer_tags eq "") {
    print $id,',"',$predicted_tags_str,'"',"\n";
  } else {
    print $id,',',$predicted_tags_str,',',$answer_tags,"\n";
  }
}
$fh->close;

sub predict_tag_score {
  my ($tag, $title_tfidf, $body_tfidf) = @_;
  my $tag_with_features = {};
  $tag_with_features->{'title_cosine'} = get_cosine_similarity($title_tfidf, $m->{$tag});
  $tag_with_features->{'body_cosine'} = get_cosine_similarity($body_tfidf, $btm->{$tag});
  if($tag_with_features->{'title_cosine'}==0 && $tag_with_features->{'body_cosine'}==0) {
    $tag_with_features->{'tag_weight_zero_cosine'} = log($tag_weights->{$tag});
    $tag_with_features->{'tag_weight_nonzero_cosine'} = 0.0;
  } else {
    $tag_with_features->{'tag_weight_zero_cosine'} = 0.0;
    $tag_with_features->{'tag_weight_nonzero_cosine'} = log($tag_weights->{$tag});
  }
  my $p_score = predict_features_score($tag_with_features);
}

sub predict_features_score {
  my $score = $fw->{'Bias'};
  my ($tag_with_features) = @_;
  foreach my $f (keys %{$tag_with_features}) {
    $score += (($tag_with_features->{$f} - $fc->{$f}) / $fs->{$f}) * $fw->{$f}
  }
  return $score;
}

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
    foreach my $ng (sort{$tfidfs->{$b} <=> $tfidfs->{$a}} keys %{$tfidfs}) {
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
