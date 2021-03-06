. cmd.sh
. path.sh

LMWT=9
wip=0.0

. ./utils/parse_options.sh

dir=$1 # e.g. exp/chain/tdnn_1d_aug_sp_ftv/decode_final_test_taibun
graph=$2
output_file=$3
output_dir=$(dirname $output_file)
symtab=$graph/words.txt
hyp_filtering_cmd="local/wer_hyp_filter"
mkdir -p $output_dir

lattice-scale --inv-acoustic-scale=$LMWT "ark:gunzip -c $dir/lat.*.gz|" ark:- | \
lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- | \
lattice-best-path --word-symbol-table=$symtab ark:- ark,t:- | \
utils/int2sym.pl -f 2- $symtab | \
$hyp_filtering_cmd > $3 || exit 1;
