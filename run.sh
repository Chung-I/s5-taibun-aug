#!/usr/bin/env bash
#
# Copyright 2018, Yuan-Fu Liao, National Taipei University of Technology, yfliao@mail.ntut.edu.tw
#
# Before you run this recipe, please apply, download and put or make a link of the corpus under this folder (folder name: "NER-Trs-Vol1").
# For more detail, please check:
# 1. Formosa Speech in the Wild (FSW) project (https://sites.google.com/speech.ntut.edu.tw/fsw/home/corpus)
# 2. Formosa Speech Recognition Challenge (FSW) 2018 (https://sites.google.com/speech.ntut.edu.tw/fsw/home/challenge)
stage=-2
num_jobs=10

testsets="test test_pts test_pts_merged"
tat_dir=TAT-Vol1-train-lavalier
pts_dir=PTS_TW-train

# shell options
set -eo pipefail

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

# configure number of jobs running in parallel, you should adjust these numbers according to your machines
# data preparation
if [ $stage -le -2 ]; then

  # Lexicon Preparation,
  echo "$0: Lexicon Preparation"
  local/prepare_dict.sh language/lexiconp.txt data/local/dict || exit 1;

  ## Data Preparation
  echo "$0: Data Preparation"
  rm -rf   data/pts data/tat data/tat_all1 data/test_pts data/train data/test data/eval data/pts_merged data/test_pts_merged data/local/train
  mkdir -p data/local/train
  local/prepare_data.sh --train-dir $tat_dir --data-dir data/tat_all || exit 1;
  local/prepare_pts_data.sh --train-dir $pts_dir --data-dir data/pts_all || exit 1;
  python3 local/combine_consecutive_segments.py data/pts_all data/pts_all_merged || exit 1;
  utils/fix_data_dir.sh data/pts_all_merged || exit 1;
  grep -E "G20194590170" data/pts_all/utt2spk | awk '{print $2}' > data/pts_all/cv.spk
  grep -E "G20194590170" data/pts_all_merged/utt2spk | awk '{print $2}' > data/pts_all_merged/cv.spk
  grep -E "(IU_IUF0008|IU_IUM0012|KK_KKM0001|KH_KHF0008|IU_IUF0005|TS_TSF0017|IU_IUM0009|KK_KKM0006)" data/tat_all/utt2spk | awk '{print $2}' > data/tat_all/cv1.spk
  grep -E "(TA_TAM0001|IU_IUF0013|KH_KHF0003|IU_IUM0014|TH_THF0021|TH_THM0011|TH_THF0005|KK_KKF0013)" data/tat_all/utt2spk | awk '{print $2}' > data/tat_all/cv2.spk
  utils/subset_data_dir_tr_cv.sh --cv-spk-list data/pts_all/cv.spk data/pts_all data/pts data/test_pts
  utils/subset_data_dir_tr_cv.sh --cv-spk-list data/pts_all_merged/cv.spk data/pts_all_merged data/pts_merged data/test_pts_merged
  utils/subset_data_dir_tr_cv.sh --cv-spk-list data/tat_all/cv1.spk data/tat_all data/tat_all1 data/eval
  utils/subset_data_dir_tr_cv.sh --cv-spk-list data/tat_all/cv2.spk data/tat_all1 data/tat data/test
  cat data/pts/text data/tat/text | awk '{$1=""}1;' | awk '{$1=$1}1;' > data/local/train/text


  # Phone Sets, questions, L compilation
  echo "$0: Phone Sets, questions, L compilation Preparation"
  rm -rf data/lang
  utils/prepare_lang.sh --position-dependent-phones false data/local/dict \
      "<SIL>" data/local/lang data/lang || exit 1;

  # LM training
  echo "$0: LM training"
  rm -rf data/local/lm/3gram-mincount
  local/train_lms.sh data/local/lm || exit 1;

  # G compilation, check LG composition
  echo "$0: G compilation, check LG composition"
  utils/format_lm.sh data/lang data/local/lm/3gram-mincount/lm_unpruned.gz \
      data/local/dict/lexiconp.txt data/lang_test || exit 1;
fi

# Now make MFCC plus pitch features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=mfcc

# mfcc
if [ $stage -le -1 ]; then
  echo "$0: making mfccs"
  for x in tat pts test eval test_pts pts_merged test_pts_merged ; do
    steps/make_mfcc_pitch.sh --cmd "$train_cmd" --nj $num_jobs data/$x exp/make_mfcc/$x $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
    utils/fix_data_dir.sh data/$x || exit 1;
  done
fi

# mono
if [ $stage -le 0 ]; then
  echo "$0: train mono model"
  # Make some small data subsets for early system-build stages.
  echo "$0: make training subsets"
  utils/subset_data_dir.sh --shortest data/tat 3000 data/tat_mono

  ## train mono
  steps/train_mono.sh --boost-silence 1.25 --cmd "$train_cmd" --nj $num_jobs \
    data/tat_mono data/lang exp/mono || exit 1;

  ## Get alignments from monophone system.
  steps/align_si.sh --boost-silence 1.25 --cmd "$train_cmd" --nj $num_jobs \
    data/tat data/lang exp/mono exp/mono_ali || exit 1;

  # Monophone decoding
  (
  utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1;
  for testset in $testsets ; do
    numspk=$(wc -l <data/${testset}/spk2utt)
    nj=$([[ $numspk -le $num_jobs ]] && echo "$numspk" || echo "$num_jobs")
    echo $numspk
    echo $nj
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj $nj \
      exp/mono/graph data/$testset exp/mono/decode_${testset}
  done
  )&
fi

# tri1
if [ $stage -le 1 ]; then
  echo "$0: train tri1 model"
  # train tri1 [first triphone pass]
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
   2500 20000 data/tat data/lang exp/mono_ali exp/tri1 || exit 1;

  # align tri1
  utils/data/combine_data.sh data/train data/pts data/tat || exit 1 ;
  steps/align_si.sh --cmd "$train_cmd" --nj $num_jobs \
    data/train data/lang exp/tri1 exp/tri1_ali || exit 1;

  # decode tri1
  (
  utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;
  for testset in $testsets ; do
    numspk=$(wc -l <data/${testset}/spk2utt)
    nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj $nj \
      exp/tri1/graph data/$testset exp/tri1/decode_${testset}
  done
  )&
fi

# tri2
if [ $stage -le 2 ]; then
  echo "$0: train tri2 model"
  # train tri2 [delta+delta-deltas]
  steps/train_deltas.sh --cmd "$train_cmd" \
   3000 24000 data/train data/lang exp/tri1_ali exp/tri2 || exit 1;

  # align tri2b
  steps/align_si.sh --cmd "$train_cmd" --nj $num_jobs \
    data/train data/lang exp/tri2 exp/tri2_ali || exit 1;

  # decode tri2
  #(
  utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph
  for testset in $testsets ; do
    numspk=$(wc -l <data/${testset}/spk2utt)
    nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj $nj \
      exp/tri2/graph data/$testset exp/tri2/decode_${testset}
  done
  #)&
fi

# tri3a
if [ $stage -le 3 ]; then
  echo "$-: train tri3 model"
  # Train tri3a, which is LDA+MLLT,
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
   4000 32000 data/train data/lang exp/tri2_ali exp/tri3a || exit 1;

  #ln -s exp/tri3a exp/tri3 ;
  #local/run_learn_lex_bayesian.sh --stage 1 --test-set $testsets --oov-symbol "<SIL>" \
  #  --nj $num_jobs --decode-nj $num_jobs || exit 1;

  # decode tri3a
  #(
  utils/mkgraph.sh data/lang_test exp/tri3a exp/tri3a/graph || exit 1;
  for testset in $testsets ; do
    numspk=$(wc -l <data/${testset}/spk2utt)
    nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
    steps/decode.sh --cmd "$decode_cmd" --nj $nj --config conf/decode.config \
      exp/tri3a/graph data/${testset} exp/tri3a/decode_${testset}
  done
  #)&
fi

# tri4
if [ $stage -le 4 ]; then
  echo "$0: train tri4 model"
  # From now, we start building a more serious system (with SAT), and we'll
  # do the alignment with fMLLR.
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $num_jobs \
    data/train data/lang exp/tri3a exp/tri3a_ali || exit 1;

  steps/train_sat.sh --cmd "$train_cmd" \
    5000 40000 data/train data/lang exp/tri3a_ali exp/tri4a || exit 1;

  steps/cleanup/segment_long_utterances.sh --nj $num_jobs exp/tri4a data/lang \
    data/pts_merged data/pts_reseg exp/pts_merged_tri4a || exit 1;
  steps/compute_cmvn_stats.sh \
    data/pts_reseg exp/make_mfcc/pts_reseg mfcc || exit 1;
  utils/fix_data_dir.sh data/pts_reseg || exit 1;
  steps/cleanup/clean_and_segment_data.sh --nj $num_jobs data/pts_reseg data/lang \
    exp/pts_merged_tri4a exp/pts_merged_tri4a_cleanup data/pts_reseg_cleaned || exit 1;
  mv data/train data/old_train || exit 1;
  utils/data/combine_data.sh data/train data/pts_reseg_cleaned data/tat || exit 1 ;


  # align tri4a
  steps/align_fmllr.sh  --cmd "$train_cmd" --nj $num_jobs \
    data/train data/lang exp/tri4a exp/tri4a_ali

  # decode tri4a
  #(
  utils/mkgraph.sh data/lang_test exp/tri4a exp/tri4a/graph
  for testset in $testsets ; do
    numspk=$(wc -l <data/${testset}/spk2utt)
    nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
    steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nj --config conf/decode.config \
      exp/tri4a/graph data/${testset} exp/tri4a/decode_${testset}
  done
  #)&
fi

# tri5
if [ $stage -le 5 ]; then
  echo "$0: train tri5 model"
  # Building a larger SAT system.
  steps/train_sat.sh --cmd "$train_cmd" \
    5000 100000 data/train data/lang exp/tri4a_ali exp/tri5a || exit 1;

  # align tri5a
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $num_jobs \
    data/train data/lang exp/tri5a exp/tri5a_ali || exit 1;

  # decode tri5
  #(
  utils/mkgraph.sh data/lang_test exp/tri5a exp/tri5a/graph || exit 1;
  for testset in $testsets ; do
    numspk=$(wc -l <data/${testset}/spk2utt)
    nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
    steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nj --config conf/decode.config \
      exp/tri5a/graph data/${testset} exp/tri5a/decode_${testset} || exit 1;
  done
  #)&
fi

# nnet3 tdnn models
# commented out by default, since the chain model is usually faster and better
#if [ $stage -le 6 ]; then
  # echo "$0: train nnet3 model"
  # local/nnet3/run_tdnn.sh
#fi

# chain model
if [ $stage -le 7 ]; then
  # The iVector-extraction and feature-dumping parts coulb be skipped by setting "--train_stage 7"
  echo "$0: train chain model"
  local/chain/run_tdnn.sh --test-sets "$testsets"
fi

# getting results (see RESULTS file)
if [ $stage -le 8 ]; then
  echo "$0: extract the results"
  for test_set in $testsets ; do
  echo "WER: $test_set"
  for x in exp/*/decode_${test_set}; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done 2>/dev/null
  for x in exp/*/*/decode_${test_set}; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done 2>/dev/null
  echo

  echo "CER: $test_set"
  for x in exp/*/decode_${test_set}; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null
  for x in exp/*/*/decode_${test_set}; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null
  echo
  done
fi

#if [ $stage -le 9 ]; then
#  dict_tmp=data/local/dict_mandarin
#  lang_tmp=data/local/lang_mandarin
#  lang_dir=data/lang_mandarin
#  src_mdl_dir=exp/chain/tdnn_1d_aug_sp
#  #cp -r data/local/dict  $dict_tmp
#  #cp language/mandarin_lexiconp.txt $dict_tmp/lexiconp.txt
#  #echo "<SIL> 1.0 SIL"	>> $dict_tmp/lexiconp.txt
#  #perl -ape 's/(\S+\s+)\S+\s+(.+)/$1$2/;' < $dict_tmp/lexiconp.txt > $dict_tmp/lexicon.txt || exit 1;
#
#  #utils/prepare_lang.sh --position-dependent-phones false \
#  #  --phone-symbol-table $src_mdl_dir/phones.txt $dict_tmp "<SIL>" $lang_tmp $lang_dir || exit 1;
#
#  bash local/run_learn_lex_bayesian.sh --ref-dict $dict_tmp --dir exp/chain/tdnn_1d_aug_sp_lex_work \
#    --data data/great_times_hires --src-mdl-dir exp/chain/tdnn_1d_aug_sp --ref-lang $lang_dir \
#    --oov-symbol "<SIL>" --g2p-lexicon-path language/mandarin_oov_g2p_lexiconp.txt --stage 1 --lexlearn-stage 5 || exit 1
#fi

#if [ $stage -le 10 ]; then
#  #utils/combine_data.sh data/train_aug_sp_gt_hires "data/train_aug_sp_hires data/great_times_hires"
#  #utils/combine_data.sh data/train_aug_sp_gt "data/train_aug_sp data/great_times"
#  steps/combine_ali_dirs.sh --nj 12 data/${train_set}_aug_sp_gt_hires exp/tri5a_aug_sp_gt_lats exp/tri5a_aug_sp_lats exp/chain/tdnn_1d_aug_sp_ali_great_times_hires || exit 1;
#fi
# finish
echo "$0: all done"

exit 0;
