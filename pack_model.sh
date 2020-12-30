lang=data/lang_mandarin_test
model=exp/chain/tdnn_1d_aug_sp
graph=exp/chain/tdnn_1d_aug_sp/graph_mandarin
output_dir=exp/chain/nnet_online_mandarin 
bash steps/online/nnet3/prepare_online_decoding.sh --add-pitch true $lang exp/nnet3/extractor $model $output_dir
tar -cv -f $1 $lang
tar -rv -f $1 $output_dir
tar -rv -f $1 $graph
#tar -rv -f $1 $model/decode_great_times/lat.*.gz
