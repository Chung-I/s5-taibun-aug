. ./path.sh
test_text="lms/test_text_balanced"
#cat data/abula_big/text data/pts_tw_extra_mandarin/text | cut -d " " -f2- > $test_text
#python3 dict_seg.py language/mandarin_120k_phn_fixed_lexiconp.txt $test_text ${test_text}_seg  --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data --lower --non-hanzi-in-lexicon
#mv ${test_text}_seg $test_text

#train_text_array=("TSM/segbyNCTUparser-train-noabula-lexiconseg.txt" "language/pts_taibun_mandarin_text_seg")
#train_texts="TSM/segbyNCTUparser-train-noabula-mixseg.txt language/pts_taibun_mandarin_text_seg_mix"
train_text_array=("TSM/segbyNCTUparser-train-noabula-mixseg.txt" "language/pts_taibun_mandarin_text_seg_mix")
train_text_name=("ftv" "ftv_default")
vocab="language/mandarin_vocab.txt"
lms=$1
mkdir -p $lms

for disc in wbdiscount kndiscount ukndiscount;
do
  ppls=""
  for ((i=0; i<${#train_text_array[@]}; i++));
  do
    ppl_file="$lms/${train_text_name[i]}_srilm_${disc}.ppl"
    lm_file=$lms/${train_text_name[i]}_srilm_${disc}.arpa
    #./train_lm.sh --stage 0 --discount-type $disc ${train_text_array[i]} $vocab $lm_file
    #./test_lm.sh $lm_file $test_text $ppl_file
    ppls="$ppls $ppl_file"
  done
  compute-best-mix lambda="0.5 0.5" $ppls
  #./train_lms_and_interpolate.sh --stage 0 --discount-type $disc "$train_texts" $vocab lms/srilm_${disc}.arpa $test_text lms/srilm_${disc}.ppl 
done

#./train_lms_and_interpolate.sh --stage 0 --lm-type kenlm "$train_texts" $vocab lms/kenlm.arpa $test_text lms/kenlm.ppl 
