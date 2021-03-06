. cmd.sh
. path.sh

LMWT=9
wip=0.0
stage=0

. ./utils/parse_options.sh

dir=$1 # e.g. exp/chain/tdnn_1d_aug_sp_ftv/decode_final_test_taibun
model=$2 # e.g. exp/chain/tdnn_1d_aug_sp_ftv/final.mdl
output_file=$3
output_dir=$(dirname $output_file)
phn_symtab=$(dirname $dir)/phones.txt

if [ $stage -le 0 ];
then
  lattice-scale --inv-acoustic-scale=$LMWT "ark:gunzip -c $dir/lat.*.gz|" ark:- | \
  lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- | \
  lattice-1best ark:- ark:- | \
  nbest-to-linear ark:- ark:- | \
  ali-to-phones $model ark:- ark,t:- | \
  utils/int2sym.pl -f 2- $phn_symtab > $output_file.phn
fi

if [ $stage -le 1 ];
then
  paste -d " " <(cut $output_file.phn -d " " -f1) <(cut $output_file.phn -d " " -f2- | perl -ape 's/(iNULL|SIL) / /g' | perl -ape 's/([^\d]) /$1/g') | perl -ape 's/[ \t]+/ /g' > $output_file
fi

