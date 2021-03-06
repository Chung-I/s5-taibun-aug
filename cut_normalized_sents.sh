lexicon_path=$1
for file in ftv/tmp/only_text-*;
do
  python3 dict_seg.py $lexicon_path $file $file-seg --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data
done
