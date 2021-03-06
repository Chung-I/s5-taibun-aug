diff_type=mutual_er

. ./utils/parse_options.sh || exit 1;

dir=$1
dest_path=$2

python3 generate_consensus.py $dir/scoring_kaldi $dest_path.chars.txt --suffix ".chars." --diff-type $diff_type
echo "consensus CER:"
./compute_wer_kaldi.sh $dir/scoring_kaldi/test_filt.chars.txt $dest_path.chars.txt 
echo "best CER:"
cat $dir/scoring_kaldi/best_cer

python3 generate_consensus.py $dir/scoring_kaldi $dest_path.txt --diff-type $diff_type 
echo "consensus WER:"
./compute_wer_kaldi.sh $dir/scoring_kaldi/test_filt.txt  $dest_path.txt
echo "best WER:"
cat $dir/scoring_kaldi/best_wer

local/char_tokenizer.sh $dest_path.txt $dest_path.word.chars.txt
echo "CER by word-level consensus:"
./compute_wer_kaldi.sh $dir/scoring_kaldi/test_filt.chars.txt  $dest_path.word.chars.txt
