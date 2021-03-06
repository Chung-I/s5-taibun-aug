. ./path.sh

stage=0
best_discount_type=ukndiscount
best_lm_weight=
skip_interpolate=false
final_test_set=false

. ./utils/parse_options.sh || exit 1;
#test_text="language/tshingtshun_taibun_text_test_seg"
#python3 dict_seg.py language/mandarin_120k_phn_fixed_lexiconp.txt $test_text ${test_text}_seg  --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data --lower --non-hanzi-in-lexicon
#mv ${test_text}_seg $test_text


#train_texts="TSM/segbyNCTUparser-train-noabula-lexiconseg.txt language/pts_taibun_mandarin_text_seg"
#train_text_array=("TSM/segbyNCTUparser-train-noabula-lexiconseg.txt" "language/pts_taibun_mandarin_text_seg")
train_text_array=("TSM/segbyNCTUparser-train-noabula.txt" "TSM/segbyNCTUparser-train-noabula-lexiconseg.txt" "language/pts_taibun_mandarin_text_seg" "language/pts_taibun_mandarin_text_seg_default" "language/tshingtshun_taibun_mandarin_text_full_seg" "language/tshingtshun_taibun_mandarin_text_full_seg_default" "language/pts_tw_extra_mandarin_text_seg" "language/pts_tw_extra_mandarin_text_seg_default")
#train_text_array=("TSM/segbyNCTUparser-train-noabula.txt" "TSM/segbyNCTUparser-train-noabula-lexiconseg.txt" "language/pts_taibun_mandarin_text_seg" "language/pts_taibun_mandarin_text_seg_default" "language/tshingtshun_taibun_mandarin_text_train_seg" "language/tshingtshun_taibun_mandarin_text_train_seg_default")
train_text_name=("ftv" "ftv_default" "train" "train_default" "tshingtshun" "tshingtshun_default" "pts_tw_extra_mandarin" "pts_tw_extra_mandarin_default")
vocab="language/mandarin_vocab.txt"
lms=$1
dest_lm_file=$2


mkdir -p $lms

test_text=$lms/test_text
if $final_test_set ;
then
  test_texts=""
  for LMWT in 7 8 9;
  do
    for word_ins in 0.0 0.5 1.0;
    do
      test_texts="$test_texts exp/chain/tdnn_1d_aug_sp_ftv_ivector/decode_final_test_chinese_srilm_alltext_equal_lmwt/scoring_kaldi/penalty_${word_ins}/${LMWT}.txt"
    done
  done
  cat $test_texts | cut -d " " -f2- > $test_text
else
  cat <(cat language/tshingtshun_taibun_mandarin_text_test_seg | shuf -n 3000) <(cat data/pts_tw_extra_mandarin/text | cut -d " " -f2- | shuf -n 3000) <(cat data/abula_big/text | cut -d " " -f2- | shuf -n 3000) > $test_text
fi

if [ $stage -le 0 ];
then
  for disc in wbdiscount kndiscount ukndiscount;
  do
    ppls=""
    for ((i=0; i<${#train_text_array[@]}; i++));
    do
      ppl_file=$lms/${train_text_name[i]}_srilm_${disc}.ppl
      lm_file=$lms/${train_text_name[i]}_srilm_${disc}.arpa
      ./train_lm.sh --stage 0 --discount-type $disc ${train_text_array[i]} $vocab $lm_file
      ./test_lm.sh $lm_file $test_text $ppl_file
      ppls="$ppls $ppl_file"
    done
    compute-best-mix lambda="0.125 0.125 0.125 0.125 0.125 0.125 0.125 0.125" $ppls
    #./train_lms_and_interpolate.sh --stage 0 --discount-type $disc "$train_texts" $vocab lms/srilm_${disc}.arpa $test_text lms/srilm_${disc}.ppl 
  done
fi

if [ $stage -le 1 ] && ! $skip_interpolate;
then
  lm_files=""
  for ((i=0; i<${#train_text_array[@]}; i++));
  do
    lm_files="$lm_files $lms/${train_text_name[i]}_srilm_${best_discount_type}.arpa"
  done
  echo $lm_files
  echo $best_lm_weight
  ./interpolate_lms.sh "$lm_files" $dest_lm_file "$best_lm_weight"
  #./test_lm.sh $dest_lm_file $test_text ${dest_lm_file}.ppl
fi

