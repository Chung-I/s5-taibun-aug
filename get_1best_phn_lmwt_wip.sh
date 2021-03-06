. cmd.sh
. path.sh

cmd=run.pl

word_ins_penalty=0.0,0.5,1.0
min_lmwt=7
max_lmwt=17
wip=0.0
stage=0

. ./utils/parse_options.sh

data=$1
dir=$2 # e.g. exp/chain/tdnn_1d_aug_sp_ftv/decode_final_test_taibun
model=$3 # e.g. exp/chain/tdnn_1d_aug_sp_ftv/final.mdl
phn_symtab=$(dirname $dir)/phones.txt

ref_filtering_cmd="cat"
[ -x local/wer_output_filter ] && ref_filtering_cmd="local/wer_output_filter"
[ -x local/wer_ref_filter ] && ref_filtering_cmd="local/wer_ref_filter"

mkdir -p $dir/scoring_kaldi
cat $data/text | $ref_filtering_cmd > $dir/scoring_kaldi/test_filt.txt || exit 1;

if [ $stage -le 0 ];
then
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_kaldi/penalty_$wip/log/best_path.LMWT.log \
      lattice-scale --inv-acoustic-scale=LMWT "ark:gunzip -c $dir/lat.*.gz|" ark:- \| \
      lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
      lattice-1best ark:- ark:- \| \
      nbest-to-linear ark:- ark:- \| \
      ali-to-phones $model ark:- ark,t:- \| \
      utils/int2sym.pl -f 2- $phn_symtab '>' $dir/scoring_kaldi/penalty_$wip/LMWT.phn.txt || exit 1; 
  done
fi

if [ $stage -le 1 ];
then
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    for lmwt in $(seq $min_lmwt $max_lmwt); do
      prefix=$dir/scoring_kaldi/penalty_$wip/$lmwt
      paste -d " " <(cut $prefix.phn.txt -d " " -f1) <(cut $prefix.phn.txt -d " " -f2- | perl -ape 's/(iNULL|SIL) / /g' | perl -ape 's/([^\d]) /$1/g') | perl -ape 's/[ \t]+/ /g' > $prefix.syl.txt || exit 1;
    done
  done
fi

if [ $stage -le 2 ];
then
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_kaldi/penalty_$wip/log/score.ser.LMWT.log \
      cat $dir/scoring_kaldi/penalty_$wip/LMWT.syl.txt \| \
      compute-wer --text --mode=present \
      ark:$dir/scoring_kaldi/test_filt.txt  ark,p:- ">&" $dir/ser_LMWT_$wip || exit 1;
  done
fi

if [ $stage -le 3 ] ; then
  for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    for lmwt in $(seq $min_lmwt $max_lmwt); do
      # adding /dev/null to the command list below forces grep to output the filename
      grep WER $dir/ser_${lmwt}_${wip} /dev/null
    done
  done | utils/best_wer.sh  >& $dir/scoring_kaldi/best_ser || exit 1

  best_ser_file=$(awk '{print $NF}' $dir/scoring_kaldi/best_ser)
  best_wip=$(echo $best_ser_file | awk -F_ '{print $NF}')
  best_lmwt=$(echo $best_ser_file | awk -F_ '{N=NF-1; print $N}')

  if [ -z "$best_lmwt" ]; then
    echo "$0: we could not get the details of the best SER from the file $dir/ser_*.  Probably something went wrong."
    exit 1;
  fi

  if $stats; then
    mkdir -p $dir/scoring_kaldi/ser_details
    echo $best_lmwt > $dir/scoring_kaldi/ser_details/lmwt # record best language model weight
    echo $best_wip > $dir/scoring_kaldi/ser_details/wip # record best word insertion penalty

    $cmd $dir/scoring_kaldi/log/stats1.ser.log \
      cat $dir/scoring_kaldi/penalty_$best_wip/${best_lmwt}.syl.txt \| \
      align-text --special-symbol="'***'" ark:$dir/scoring_kaldi/test_filt.txt ark:- ark,t:- \|  \
      utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" \| tee $dir/scoring_kaldi/ser_details/per_utt \|\
       utils/scoring/wer_per_spk_details.pl $data/utt2spk \> $dir/scoring_kaldi/ser_details/per_spk || exit 1;

    $cmd $dir/scoring_kaldi/log/stats2.ser.log \
      cat $dir/scoring_kaldi/ser_details/per_utt \| \
      utils/scoring/wer_ops_details.pl --special-symbol "'***'" \| \
      sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 \> $dir/scoring_kaldi/ser_details/ops || exit 1;

    $cmd $dir/scoring_kaldi/log/ser_bootci.ser.log \
      compute-wer-bootci --mode=present \
        ark:$dir/scoring_kaldi/test_filt.txt ark:$dir/scoring_kaldi/penalty_$best_wip/${best_lmwt}.txt \
        '>' $dir/scoring_kaldi/cer_details/ser_bootci || exit 1;

  fi
fi

# If we got here, the scoring was successful.
# As a  small aid to prevent confusion, we remove all wer_{?,??} files;
# these originate from the previous version of the scoring files
# i keep both statement here because it could lead to confusion about
# the capabilities of the script (we don't do cer in the script)
rm $dir/wer_{?,??} 2>/dev/null
rm $dir/cer_{?,??} 2>/dev/null

exit 0;
