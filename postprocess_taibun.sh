. cmd.sh
. path.sh

src_dir=taibun_text_corpus
dest_dir=taibun_text_corpus_cutted

stage=-1

. ./utils/parse_options.sh

mkdir -p $dest_dir

#for file in $src_dir/*;
#do
#  basefile=$(basename $file)
#  prefix=$dest_dir/$basefile
#  python3 normalize_g2p_taibun.py $file $prefix-normalized || exit 1;
#  python3 dict_seg.py language/lexiconp.txt $prefix-normalized $prefix-seg-normalized --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data --non-hanzi-in-lexicon || exit 1;
#  bash fix_common_taibun_mistakes.sh $prefix-seg-normalized ${prefix}_seg || exit 1;
#  python3 dict_seg.py language/tailo_lexiconp.txt $prefix-normalized $prefix-seg-default-normalized --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data --non-hanzi-in-lexicon || exit 1;
#  bash fix_common_taibun_mistakes.sh $prefix-seg-default-normalized ${prefix}_seg_default || exit 1;
#  rm $prefix-normalized $prefix-seg-normalized $prefix-seg-default-normalized
#done
for file in $src_dir/*;
do
  basefile=$(basename $file)
  prefix=$dest_dir/$basefile
  bash fix_common_taibun_mistakes.sh ${prefix}_seg ${prefix}_seg_tmp || exit 1;
  mv ${prefix}_seg_tmp ${prefix}_seg
  bash fix_common_taibun_mistakes.sh ${prefix}_seg_default ${prefix}_seg_default_tmp || exit 1;
  mv ${prefix}_seg_default_tmp ${prefix}_seg_default
done
