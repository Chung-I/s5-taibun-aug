. ./path.sh
#lattice-1best ark:"gunzip -c exp/chain/tdnn_1d_aug_sp/decode_abula_new/lat.1.gz|" ark:- | \
#  nbest-to-linear ark:- ark:ali.1 'ark,t:|int2sym.pl -f 2- exp/chain/tdnn_1d_aug_sp/graph_mandarin/words.txt > text' 
#lattice-1best ark:"gunzip -c exp/chain/tdnn_1d_aug_sp/decode_abula_new/lat.1.gz|" ark:- | \
#  nbest-to-linear ark:- ark:- | ali-to-phones exp/chain/tdnn_1d_aug_sp/final.mdl ark:- 'ark,t:|int2sym.pl -f 2- exp/chain/tdnn_1d_aug_sp/graph_mandarin/phones.txt > phn_text' 
lattice-scale --inv-acoustic-scale=1 ark:"gunzip -c exp/chain/tdnn_1d_aug_sp/decode_abula_new/lat.1.gz|" ark:- | lattice-best-path ark:- 'ark,t:|int2sym.pl -f 2- exp/chain/tdnn_1d_aug_sp/graph_mandarin/words.txt > best_text.1' ark:1.ali
