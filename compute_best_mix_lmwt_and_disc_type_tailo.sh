. ./path.sh

stage=0
best_discount_type=ukndiscount
best_lm_weight=
skip_interpolate=false
order=5

. ./utils/parse_options.sh || exit 1;
#test_text="language/tshingtshun_taibun_text_test_seg"
#cat data/abula_big/text data/pts_tw_extra_mandarin/text | cut -d " " -f2- > $test_text
#python3 dict_seg.py language/mandarin_120k_phn_fixed_lexiconp.txt $test_text ${test_text}_seg  --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data --lower --non-hanzi-in-lexicon
#mv ${test_text}_seg $test_text

#train_texts="TSM/segbyNCTUparser-train-noabula-lexiconseg.txt language/pts_taibun_mandarin_text_seg"
#train_text_array=("TSM/segbyNCTUparser-train-noabula-lexiconseg.txt" "language/pts_taibun_mandarin_text_seg")
train_text_array=("language/taibun_ftv_seg_syl" "language/taibun_train_seg_syl" "language/pts_tw_extra_text_syl" "language/tshingtshun_taibun_text_full_seg_syl")
#train_text_array=("language/taibun_ftv_seg" "language/taibun_ftv_seg_default" "language/taibun_train_seg" "language/taibun_train_seg_default" "language/tshingtshun_taibun_text_train_seg" "language/tshingtshun_taibun_text_train_seg_default")
train_text_name=("ftv" "train" "pts_tw_extra" "tshingtshun")
vocab="language/tailo_num_vocab.txt"
lms=$1
test_text=$2
dest_lm_file=$3

mkdir -p $lms

if [ $stage -le 0 ];
then
  for disc in wbdiscount kndiscount ukndiscount;
  do
    ppls=""
    for ((i=0; i<${#train_text_array[@]}; i++));
    do
      ppl_file="$lms/${train_text_name[i]}_srilm_${disc}.ppl"
      lm_file=$lms/${train_text_name[i]}_srilm_${disc}.arpa
      ./train_lm.sh --stage 0 --discount-type $disc --order $order ${train_text_array[i]} $vocab $lm_file
      ./test_lm.sh --order $order $lm_file $test_text $ppl_file
      ppls="$ppls $ppl_file"
    done
    compute-best-mix lambda="0.25 0.25 0.25 0.25" $ppls
    #./train_lms_and_interpolate.sh --stage 0 --discount-type $disc "$train_texts" $vocab lms/srilm_${disc}.arpa $test_text lms/srilm_${disc}.ppl 
  done
fi

if [ $stage -le 1 ] && ! $skip_interpolate ;
then
  lm_files=""
  for ((i=0; i<${#train_text_array[@]}; i++));
  do
    lm_files="$lm_files $lms/${train_text_name[i]}_srilm_${best_discount_type}.arpa"
  done
  echo $lm_files
  echo $best_lm_weight
  ./interpolate_lms.sh --order $order "$lm_files" $dest_lm_file "$best_lm_weight"
  ./test_lm.sh --order $order $dest_lm_file $test_text ${dest_lm_file}.ppl
fi

