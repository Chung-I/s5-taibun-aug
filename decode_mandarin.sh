# Set up the environment variables (again)
. cmd.sh
. path.sh
 
# Set the paths of our input files into variables
phones_src=exp/chain/tdnn_1d_aug_sp/phones.txt
dict_src=../s5-mandarin/data/local/dict
lm_src=../s5-mandarin/data/local/lm/3gram-mincount/lm_unpruned
 
lang=data/lang_mandarin_test
dict=data/lang_mandarin
dict_tmp=data/local/dict_mandarin
lang_tmp=data/local/lang_mandarin
dir=exp/chain/tdnn_1d_aug_sp
stage=0
num_jobs=10
testset_root="pts_tw_extra"
lang_suffix="_mandarin"
mfccdir=mfcc_hires

. ./utils/parse_options.sh

testset=${testset_root}${lang_suffix}

if [ $stage -le -3 ]; then
  echo "$0: making mfccs"
  if [ -f data/${testset_root}_hires/feats.scp ]; then
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
    utils/data/limit_feature_dim.sh 0:39 data/${datadir}_hires data/${datadir}_hires_nopitch || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires_nopitch exp/make_hires/$datadir $mfccdir || exit 1;

    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 12 \
      data/${datadir}_hires_nopitch exp/nnet3${nnet3_affix}/extractor \
      exp/nnet3${nnet3_affix}/ivectors_${datadir}
  fi
fi

if [ $stage -le -2 ]; then
  cp -r data/local/dict $dict_tmp
  cp ../s5-mandarin/language/new_lexiconp.txt $dict_tmp/lexiconp.txt
  echo "<SIL> 1.0 SIL"	>> $dict_tmp/lexiconp.txt
  perl -ape 's/(\S+\s+)\S+\s+(.+)/$1$2/;' < $dict_tmp/lexiconp.txt > $dict_tmp/lexicon.txt || exit 1;
fi

 
# Compile the word lexicon (L.fst)
if [ $stage -le -1 ]; then
  utils/prepare_lang.sh --position-dependent-phones false \
    --phone-symbol-table $phones_src $dict_tmp "<SIL>" $lang_tmp $dict
   
  # Compile the grammar/language model (G.fst)
  utils/format_lm.sh $dict $lm_src.gz $dict_src/lexiconp.txt $lang
   
fi

if [ $stage -le 0 ]; then
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

  model="exp/chain/tdnn_1d_aug_sp"
  graph=$model/graph_mandarin
  rm -r $graph
  numspk=$(wc -l <data/${testset}/spk2utt)
  nj=$([ $numspk -le $num_jobs ] && echo "$numspk" || echo "$num_jobs")
  utils/mkgraph.sh --self-loop-scale 1.0 $lang $model $graph
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 12 --cmd "$decode_cmd" \
    --online-ivector-dir exp/nnet3/ivectors_${testset_root} \
    --frames-per-chunk 150 \
    $graph data/${testset}_hires $dir/decode_${testset} || exit 1;

fi
