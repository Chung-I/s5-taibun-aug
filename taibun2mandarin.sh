[ -f ./path.sh ] && . ./path.sh

cmd=run.pl
min_lmwt=7
max_lmwt=17
word_ins_penalty="0.0 0.5 1.0"
stage=0

. ./utils/parse_options.sh || exit 1;

dir=$1

if [ $stage -le 0 ];
then
  echo "stage 0"
  for wip in 0.0 0.5 1.0;
  #for wip in 0.0;
  do
    prefix=$dir/scoring_kaldi/penalty_$wip
    #$cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_kaldi/penalty_$wip/log/translate.LMWT.log \
    #  cat $dir/scoring_kaldi/penalty_$wip/LMWT.chars.txt \| \
    #  cut -d " " -f2- \| \
    #  ~/Works/mosesdecoder/bin/moses -f ~/Works/tsm_corpus/mandarin_to_tsm/taibun2mandarin_char_reorder_goodturing_gooating_numeral/model/moses.ini ">" $dir/scoring_kaldi/penalty_$wip/LMWT.chars.mandarin.txt || exit 1;
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_kaldi/penalty_$wip/log/score.LMWT.log \
      cat $prefix/LMWT.chars.txt \| cut -d " " -f1 \| \
      paste -d " " - $prefix/LMWT.chars.mandarin.txt \| \
      compute-wer --text --mode=present \
      ark:$dir/scoring_kaldi/test_filt.chars.txt  ark,p:- ">&" $dir/cer_LMWT_$wip || exit 1;
  done
fi

if [ $stage -le 1 ];
then
  echo "stage 1"
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    for lmwt in $(seq $min_lmwt $max_lmwt); do
      # adding /dev/null to the command list below forces grep to output the filename
      grep WER $dir/cer_${lmwt}_${wip} /dev/null
    done
  done | utils/best_wer.sh  >& $dir/scoring_kaldi/best_cer || exit 1
  
  best_cer_file=$(awk '{print $NF}' $dir/scoring_kaldi/best_cer)
  best_wip=$(echo $best_cer_file | awk -F_ '{print $NF}')
  best_lmwt=$(echo $best_cer_file | awk -F_ '{N=NF-1; print $N}')
  
  if [ -z "$best_lmwt" ]; then
    echo "$0: we could not get the details of the best CER from the file $dir/cer_*.  Probably something went wrong."
    exit 1;
  fi
  
  if $stats; then
    mkdir -p $dir/scoring_kaldi/cer_details
    echo $best_lmwt > $dir/scoring_kaldi/cer_details/lmwt # record best language model weight
    echo $best_wip > $dir/scoring_kaldi/cer_details/wip # record best word insertion penalty
  
    $cmd $dir/scoring_kaldi/log/stats1.cer.log \
      cat $dir/scoring_kaldi/penalty_$best_wip/${best_lmwt}.chars.txt \| \
      align-text --special-symbol="'***'" ark:$dir/scoring_kaldi/test_filt.chars.txt ark:- ark,t:- \|  \
      utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" \| tee $dir/scoring_kaldi/cer_details/per_utt \|\
       utils/scoring/wer_per_spk_details.pl $data/utt2spk \> $dir/scoring_kaldi/cer_details/per_spk || exit 1;
  
    $cmd $dir/scoring_kaldi/log/stats2.cer.log \
      cat $dir/scoring_kaldi/cer_details/per_utt \| \
      utils/scoring/wer_ops_details.pl --special-symbol "'***'" \| \
      sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 \> $dir/scoring_kaldi/cer_details/ops || exit 1;
  
    $cmd $dir/scoring_kaldi/log/cer_bootci.cer.log \
      compute-wer-bootci --mode=present \
        ark:$dir/scoring_kaldi/test_filt.chars.txt ark:$dir/scoring_kaldi/penalty_$best_wip/${best_lmwt}.chars.txt \
        '>' $dir/scoring_kaldi/cer_details/cer_bootci || exit 1;
  
  fi
fi
