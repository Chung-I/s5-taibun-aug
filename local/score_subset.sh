
cmd=run.pl
stage=0
word_ins_penalty=0.0,0.5,1.0
min_lmwt=7
max_lmwt=17
#end configuration section.

echo "$0 $@"  # Print the command line for logging
[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --stage (0|1|2)                 # start scoring script from part-way through."
  echo "    --decode_mbr (true/false)       # maximum bayes risk decoding (confusion network)."
  echo "    --min_lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "    --max_lmwt <int>                # maximum LM-weight for lattice rescoring "
  exit 1;
fi

data=$1
dir=$2
destdir=$3

subset_uttlist=$data/utt2spk

mkdir -p $destdir/scoring_kaldi

if [ $stage -le 0 ]; then

  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    mkdir -p $destdir/scoring_kaldi/penalty_$wip/log
  done
  utils/filter_scp.pl $subset_uttlist < $dir/scoring_kaldi/test_filt.txt > $destdir/scoring_kaldi/test_filt.txt || exit 1;
fi

if [ $stage -le 1 ] ; then
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do

    $cmd LMWT=$min_lmwt:$max_lmwt $destdir/scoring_kaldi/penalty_$wip/log/copy.hyp.LMWT.log \
      cat $dir/scoring_kaldi/penalty_$wip/LMWT.txt \| \
      utils/filter_scp.pl $subset_uttlist \> $destdir/scoring_kaldi/penalty_$wip/LMWT.txt || exit 1;

    $cmd LMWT=$min_lmwt:$max_lmwt $destdir/scoring_kaldi/penalty_$wip/log/score.LMWT.log \
      cat $destdir/scoring_kaldi/penalty_$wip/LMWT.txt \| \
      compute-wer --text --mode=present \
      ark:$destdir/scoring_kaldi/test_filt.txt ark,p:- ">&" $destdir/wer_LMWT_$wip || exit 1;
  done
fi

if [ $stage -le 2 ] ; then
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    for lmwt in $(seq $min_lmwt $max_lmwt); do
      # adding /dev/null to the command list below forces grep to output the filename
      grep WER $destdir/wer_${lmwt}_${wip} /dev/null
    done
  done | utils/best_wer.sh  >& $destdir/scoring_kaldi/best_wer || exit 1

  best_wer_file=$(awk '{print $NF}' $destdir/scoring_kaldi/best_wer)
  best_wip=$(echo $best_wer_file | awk -F_ '{print $NF}')
  best_lmwt=$(echo $best_wer_file | awk -F_ '{N=NF-1; print $N}')

  if [ -z "$best_lmwt" ]; then
    echo "$0: we could not get the details of the best WER from the file $dir/wer_*.  Probably something went wrong."
    exit 1;
  fi

  if $stats; then
    mkdir -p $destdir/scoring_kaldi/wer_details
    echo $best_lmwt > $destdir/scoring_kaldi/wer_details/lmwt # record best language model weight
    echo $best_wip > $destdir/scoring_kaldi/wer_details/wip # record best word insertion penalty

    $cmd $destdir/scoring_kaldi/log/stats1.log \
      cat $destdir/scoring_kaldi/penalty_$best_wip/${best_lmwt}.txt \| \
      align-text --special-symbol="'***'" ark:$destdir/scoring_kaldi/test_filt.txt ark:- ark,t:- \|  \
      utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" \| tee $destdir/scoring_kaldi/wer_details/per_utt \|\
       utils/scoring/wer_per_spk_details.pl $data/utt2spk \> $destdir/scoring_kaldi/wer_details/per_spk || exit 1;

    $cmd $destdir/scoring_kaldi/log/stats2.log \
      cat $destdir/scoring_kaldi/wer_details/per_utt \| \
      utils/scoring/wer_ops_details.pl --special-symbol "'***'" \| \
      sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 \> $destdir/scoring_kaldi/wer_details/ops || exit 1;

    $cmd $destdir/scoring_kaldi/log/cer_bootci.cer.log \
      compute-wer-bootci --mode=present \
      ark:$destdir/scoring_kaldi/test_filt.txt \
       ark:$destdir/scoring_kaldi/penalty_$best_wip/${best_lmwt}.txt \
        '>' $destdir/scoring_kaldi/wer_details/wer_bootci || exit 1;

  fi
fi

# If we got here, the scoring was successful.
# As a  small aid to prevent confusion, we remove all wer_{?,??} files;
# these originate from the previous version of the scoring files
# i keep both statement here because it could lead to confusion about
# the capabilities of the script (we don't do cer in the script)
rm $destdir/wer_{?,??} 2>/dev/null
rm $destdir/cer_{?,??} 2>/dev/null

exit 0;
