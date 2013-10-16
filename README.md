* IDFファイルを作成
  * make_idf.pl
* そのタグが付いているドキュメントに紐づくTermベクトルを用いて、タグの特徴ベクトルを作成する
  * make_tag_with_term_vector.pl
* ドキュメントと類似度の高いタグの候補を取得し、類似度や出現頻度などの特徴量を付与する
  * make_candidate_tags_with_features.pl
* ドキュメントに紐づくタグを推定する
  * predict_tags_for_test.pl
