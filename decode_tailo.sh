# Set up the environment variables (again)
. ./cmd.sh
. ./path.sh
 
# Set the paths of our input files into variables
lm_dir=data/local/lm_tailo
lm_suffix=3gram-mincount/lm_unpruned 
lm_raw=final_test_tailo_lms/combined.arpa
lm_src=$lm_dir/$lm_suffix
vocab=language/tailo_num_vocab.txt 
lm_data=data/local/train_tailo
lexicon_raw=language/tailo_num_lexicon.txt
 
lang=data/lang_tailo_test
dict=data/lang_tailo
dict_tmp=data/local/dict_tailo
lang_tmp=data/local/lang_tailo
dir=exp/chain/tdnn_1d_aug_sp
mfccdir=mfcc_hires
stage=0
num_jobs=10
segment=1
extract_features=true
extract_ivectors=true
skip_scoring=false
test_set="pts_tw_extra"
dec_dir_suffix=""
use_ivector=true
graph_dir_suffix=""
ivector_dir=

. ./utils/parse_options.sh

if [ -z $ivector_dir ]; then
  ivector_dir=exp/nnet3/ivectors_${test_set}
fi

phones_src=$dir/phones.txt
graph=$dir/graph_tailo${graph_dir_suffix}
lang=${lang}${graph_dir_suffix}

if $use_ivector ; then
  ivector_opts="--online-ivector-dir $ivector_dir"
fi

if [ $stage -le -3 ]; then
  #local/prepare_data_tailo.sh --train-dir condenser/wav --data-dir data/tat_tailo --remove-hyphen true || exit 1;
  rm -r $lm_data
  mkdir -p $lm_data
  mkdir -p $(dirname $lm_raw)
  cat data/tat_tailo/text | cut -d " " -f2- > $lm_data/text
  cat $lexicon_raw | awk '{print $1}' > $vocab
  ./train_lm.sh --stage 0 --discount-type wbdiscount --order 5 $lm_data/text $vocab $lm_raw
fi


#cp ../s5-basephn/language/new_lexiconp.txt $dict_tmp/lexiconp.txt
 
# Compile the word lexicon (L.fst)
if [ $stage -le -1 ]; then
  rm -r $lm_dir
  rm -r $dict
  rm -r $lang
  cp -r data/local/dict $dict_tmp
  cp $lexicon_raw $dict_tmp/lexicon.txt
  echo "<SIL> SIL"	>> $dict_tmp/lexicon.txt
  perl -ape 's/(\S+\s+)(.+)/${1}1.0\t$2/;' < $dict_tmp/lexicon.txt > $dict_tmp/lexiconp.txt || exit 1;
  utils/prepare_lang.sh --position-dependent-phones false \
    --phone-symbol-table $phones_src $dict_tmp "<SIL>" $lang_tmp $dict
   
  # Compile the grammar/language model (G.fst)
  #local/train_lms.sh --text data/local/train/firstpass_taibun_train_text --lexicon $dict_tmp/lexicon.txt $lm_dir
  lm_base_dir=$(dirname $lm_src) 
  mkdir -p $lm_base_dir
  cp $lm_raw $lm_src
  gzip $lm_src
  utils/format_lm.sh $dict $lm_src.gz $dict_tmp/lexiconp.txt $lang
   
  # Finally assemble the HCLG graph
fi

if [ $stage -le 0 ]; then
  rm -r $graph
  utils/mkgraph.sh --self-loop-scale 1.0 $lang $dir $graph
fi

if [ $stage -le 1 ] && $extract_features; then
  echo "$0: making mfccs"
  datadir=$test_set
  mkdir -p $mfccdir
  utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
  steps/make_mfcc_pitch.sh --nj 12 --mfcc-config conf/mfcc_hires.conf \
    --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  utils/fix_data_dir.sh data/${datadir}_hires || exit 1;
fi

if [ $stage -le 2 ] && $extract_ivectors; then
  # create MFCC data dir without pitch to extract iVector
  datadir=$test_set
  utils/data/limit_feature_dim.sh 0:39 data/${datadir}_hires data/${datadir}_hires_nopitch || exit 1;
  steps/compute_cmvn_stats.sh data/${datadir}_hires_nopitch exp/make_hires/$datadir $mfccdir || exit 1;

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 12 \
    data/${datadir}_hires_nopitch exp/nnet3${nnet3_affix}/extractor \
    exp/nnet3${nnet3_affix}/ivectors_${datadir}
fi

if [ $stage -le 3 ]; then
  #for test_set in abula ;
  [ $skip_scoring == "true" ] && skip_scoring_opts=" --skip-scoring true" || skip_scoring_opts=""
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj $num_jobs --cmd "$decode_cmd" $ivector_opts \
    --frames-per-chunk 150 $skip_scoring_opts \
    $graph data/${test_set}_hires $dir/decode_${test_set}${dec_dir_suffix} || exit 1;
fi
