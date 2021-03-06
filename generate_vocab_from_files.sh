#cat taibun_text_corpus_cutted/*_seg taibun_text_corpus_cutted/*_seg_default data/train/filtered_only_text ftv/*.segment/only_text_taibun_seg_default ftv/*.segment/only_text_taibun_seg-tailo_fix | tr '[:space:]' '[\n*]' | grep -v "^\s*$" | sort | uniq -c | sort -bnr > language/taibun_vocab_and_freq.txt
#awk '{print $2}' language/taibun_vocab_and_freq.txt > language/taibun_vocab.txt
#awk 'NR==FNR{a[$1] = 1; next} !($1 in a)' language/lexiconp.txt \
#  language/taibun_vocab.txt | python local/uniq.py > language/taibun_oov_vocab.txt
tsm_dir=/home/nlpmaster/Works/tsm_corpus 
#python3 local/filter_non_hanzi.py < language/taibun_oov_vocab.txt > language/taibun_hanzi_oov_vocab.txt
#python3 cut_hanzi.py < language/taibun_hanzi_oov_vocab.txt > language/taibun_hanzi_oov_char_vocab.txt
/home/nlpmaster/Works/mosesdecoder/bin/moses -f $tsm_dir/taibun_to_tsm/mandarin2taibun_char_reorder_goodturing_gooating_numeral/model/moses.ini < language/taibun_hanzi_oov_char_vocab.txt > language/taibun_hanzi_oov_prons.txt
paste language/taibun_hanzi_oov_vocab.txt language/taibun_hanzi_oov_prons.txt > language/taibun_oov_lexicon.txt
perl -ape 's/(\S+\s+)(.+)/${1}1.0\t$2/;' < $srcdir/taibun_oov_lexicon.txt > $srcdir/taibun_oov_lexiconp.txt || exit 1;
python3 $tsm_dir/ChhoeTaigiDatabase/syl2phone.py language/taibun_oov_lexiconp.txt syl2phone.txt lexicons/taibun_oov_phn_lexiconp.txt --col 2

