train_dir=$1
output_dir=$2
mkdir -p $output_dir
utt2txt_file=$output_dir/utt_dur_text
cat $train_dir/*/text* > $utt2txt_file
python3 local/get_after_n.py $utt2txt_file $output_dir/only_text --way after --index 2
python3 local/get_after_n.py $utt2txt_file $output_dir/only_utt --way before --index 1
#python3 dict_seg.py language/mandarin_lexiconp.txt tmp/only_text tmp/only_seg_text --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data
paste -d " " $output_dir/only_utt $output_dir/only_text > $output_dir/text
