# Set up the environment variables (again)
. cmd.sh
. path.sh
 
# Set the paths of our input files into variables
dict_src=../s5-mandarin/data/local/dict
lm_dir=data/local/lm_mandarin
lm_suffix=3gram-mincount/lm_unpruned 
lm_raw=mandarin_lms/combined.arpa
lm_src=$lm_dir/$lm_suffix
lm_type=kaldi
vocab=language/mandarin_vocab.txt
lexicon_raw=language/mandarin_120k_phn_fixed_lexiconp.txt
 
lang=data/lang_mandarin_test
dict=data/lang_mandarin
dict_tmp=data/local/dict_mandarin
lang_tmp=data/local/lang_mandarin
dir=exp/chain/tdnn_1d_aug_sp
stage=0
num_jobs=10
testset_root="pts_tw_extra"
lang_suffix="_mandarin"
extract_features=true
extract_ivectors=true
skip_scoring=false
mfccdir=mfcc_hires
dec_dir_suffix=""
use_ivector="true"
graph_dir_suffix=""
ivector_dir=

. ./utils/parse_options.sh

testset=${testset_root}${lang_suffix}

if [ -z $ivector_dir ]; then
  ivector_dir=exp/nnet3/ivectors_${testset}
fi

phones_src=$dir/phones.txt
graph=$dir/graph_mandarin${graph_dir_suffix}
lang=${lang}${graph_dir_suffix}

if $use_ivector ; then
  ivector_opts="--online-ivector-dir $ivector_dir"
fi


if [ $stage -le -2 ]; then
  cp -r data/local/dict $dict_tmp
  echo $lexicon_raw
  cp $lexicon_raw $dict_tmp/lexiconp.txt
  echo "sil 1.0 SIL"	>> $dict_tmp/lexiconp.txt
  perl -ape 's/(\S+\s+)\S+\s+(.+)/$1$2/;' < $dict_tmp/lexiconp.txt > $dict_tmp/lexicon.txt || exit 1;
fi

 
# Compile the word lexicon (L.fst)
if [ $stage -le -1 ]; then
  utils/prepare_lang.sh --position-dependent-phones false \
    --phone-symbol-table $phones_src $dict_tmp "sil" $lang_tmp $dict
  rm -r $lm_dir
  if [ $lm_type == "kaldi" ];
  then
    local/train_mandarin_lms.sh --text $ftv_lm_text --lexicon $dict_tmp/lexicon.txt $lm_dir/ftv
    local/train_mandarin_lms.sh --text $pts_lm_text --lexicon $dict_tmp/lexicon.txt $lm_dir/pts
    gunzip -c $lm_dir/ftv/$lm_suffix.gz > $ftv_lm_text.arpa
    gunzip -c $lm_dir/pts/$lm_suffix.gz > $pts_lm_text.arpa
    train_lms_and_interpolate.sh --stage 1 "$ftv_lm_text $pts_lm_text" $vocab $lm_src
  else
    lm_base_dir=$(dirname $lm_src) 
    mkdir -p $lm_base_dir
    echo "using lm $lm_raw ..."
    cp $lm_raw $lm_src
    gzip $lm_src
  fi
   
  # Compile the grammar/language model (G.fst)
  utils/format_lm.sh $dict $lm_src.gz $dict_tmp/lexiconp.txt $lang
   
fi

if [ $stage -le 0 ]; then
  rm -rf $graph
  utils/mkgraph.sh --self-loop-scale 1.0 $lang $dir $graph
fi

if [ $stage -le 1 ] && $extract_features; then
  echo "$0: making mfccs"
  if [ ! -d data/${testset} ]; then
    echo "${testset} not found; exiting..." && exit 1;
    #utils/copy_data_dir.sh data/${testset_root} data/${testset}
  fi
  if [ -f data/${testset}_hires/feats.scp ]; then
    echo "feature already generated; skipping feature extraction";
  elif [ -f data/${testset_root}_hires/feats.scp ]; then
    utils/copy_data_dir.sh data/${testset} data/${testset}_hires
    cp data/${testset_root}_hires/feats.scp data/${testset}_hires
    utils/fix_data_dir.sh data/${testset}_hires
  else
    mkdir -p $mfccdir
    datadir=$testset
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
    steps/make_mfcc_pitch.sh --nj 12 --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
    utils/fix_data_dir.sh data/${datadir}_hires || exit 1;
    # create MFCC data dir without pitch to extract iVector

  fi
fi

if [ $stage -le 2 ] && $extract_ivectors;
then
  datadir=$testset
  utils/data/limit_feature_dim.sh 0:39 data/${datadir}_hires data/${datadir}_hires_nopitch || exit 1;
  steps/compute_cmvn_stats.sh data/${datadir}_hires_nopitch exp/make_hires/$datadir $mfccdir || exit 1;
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 12 \
    data/${datadir}_hires_nopitch exp/nnet3${nnet3_affix}/extractor \
    exp/nnet3${nnet3_affix}/ivectors_${datadir}
fi

if [ $stage -le 3 ]; then
  #for test_set in abula ;
  # Finally assemble the HCLG graph
  #testset=abula
  #models="exp/mono exp/tri1 exp/tri2"
  #for model in $models ;
  #do
  #  graph=$model/graph_mandarin
  #  utils/mkgraph.sh $lang $model $graph
  #  numspk=$(wc -l <data/${testset}/spk2utt)
  #  nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
  #  steps/decode.sh --cmd "$decode_cmd" --nj $nj --config conf/decode.config \
  #    $graph data/${testset} $model/decode_${testset} || exit 1; 
  #done

  #numspk=$(wc -l <data/${testset}/spk2utt)
  #nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
  [ $skip_scoring == "true" ] && skip_scoring_opts=" --skip-scoring true" || skip_scoring_opts=""
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj $num_jobs --cmd "$decode_cmd" $ivector_opts \
    --frames-per-chunk 150 $skip_scoring_opts \
    $graph data/${testset}_hires $dir/decode_${testset}${dec_dir_suffix} || exit 1;

fi
