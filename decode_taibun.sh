# Set up the environment variables (again)
. ./cmd.sh
. ./path.sh
 
# Set the paths of our input files into variables
model=exp/chain/tdnn_1d_aug_sp
phones_src=exp/chain/tdnn_1d_aug_sp/phones.txt
dict_src=../s5-basephn/data/local/dict
lm_src=../s5-basephn/data/local/lm/3gram-mincount/lm_unpruned
 
lang=data/lang_test
dict=data/lang
dict_tmp=data/local/dict
lang_tmp=data/local/lang
dir=exp/chain/tdnn_1d_aug_sp
graph=exp/chain/tdnn_1d_aug_sp/graph
mfccdir=mfcc_hires
stage=0
segment=1
test_set="pts_tw_extra"

. ./utils/parse_options.sh

if [ $stage -le -3 ]; then
  local/prepare_pts_data.sh --train-dir PTS_TW-extra --data-dir data/$test_set || exit 1;
fi

if [ $stage -le -2 ]; then
  echo "$0: making mfccs"
  datadir=$test_set
  mkdir -p $mfccdir
  utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
  steps/make_mfcc_pitch.sh --nj 12 --mfcc-config conf/mfcc_hires.conf \
    --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  utils/fix_data_dir.sh data/${datadir}_hires || exit 1;
  # create MFCC data dir without pitch to extract iVector
  utils/data/limit_feature_dim.sh 0:39 data/${datadir}_hires data/${datadir}_hires_nopitch || exit 1;
  steps/compute_cmvn_stats.sh data/${datadir}_hires_nopitch exp/make_hires/$datadir $mfccdir || exit 1;

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 12 \
    data/${datadir}_hires_nopitch exp/nnet3${nnet3_affix}/extractor \
    exp/nnet3${nnet3_affix}/ivectors_${datadir}
  exit 0;
fi

#cp ../s5-basephn/language/new_lexiconp.txt $dict_tmp/lexiconp.txt
#echo "<SIL> 1.0 SIL"	>> $dict_tmp/lexiconp.txt
 
# Compile the word lexicon (L.fst)
#if [ $stage -le -1 ]; then
#  cp -r data/local/dict $dict_tmp
#  cp $dict_src/lexicon.txt $dict_tmp
#  perl -ape 's/(\S+\s+)(.+)/${1}1.0\t$2/;' < $dict_tmp/lexicon.txt > $dict_tmp/lexiconp.txt || exit 1;
#  utils/prepare_lang.sh --position-dependent-phones false \
#    --phone-symbol-table $phones_src $dict_tmp "<SIL>" $lang_tmp $dict
#   
#  # Compile the grammar/language model (G.fst)
#  utils/format_lm.sh $dict $lm_src.gz $dict_src/lexiconp.txt $lang
#   
#  # Finally assemble the HCLG graph
#  utils/mkgraph.sh --self-loop-scale 1.0 $lang $model $graph
#fi

if [ $stage -le 0 ]; then
  #for test_set in abula ;
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 12 --cmd "$decode_cmd" \
    --online-ivector-dir exp/nnet3/ivectors_${test_set} \
    --frames-per-chunk 150 \
    $graph data/${test_set}_hires $dir/decode_${test_set} || exit 1;
fi
