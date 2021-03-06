#train_text_array=("language/taibun_ftv_seg" "language/taibun_train_seg" "language/pts_tw_extra_text" "language/tshingtshun_taibun_text_full_seg")
train_text_array=("language/pts_tw_extra_text")

for ((i=0; i<${#train_text_array[@]}; i++));
do
  phn_file=${train_text_array[i]}_phn 
  syl_file=${train_text_array[i]}_syl
  python3 translate.py language/full_taibun_fixed_lexiconp.txt language/full_taibun_fixed_lexiconp.txt /home/nlpmaster/Works/tsm_corpus/moedict-data-twblg/uni/詞目總檔.csv ${train_text_array[i]} $phn_file --form sent --with-prob --model-types dict char --unk-consult-order prob dict bpmf --mosesserver-port 8081 --pron-only --final-n-best 1
  cat $phn_file | perl -ape 's/(iNULL|SIL) / /g' | perl -ape 's/([^\d]) /$1/g' | perl -ape 's/[ \t]+/ /g' > $syl_file
done
