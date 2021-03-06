lang_suffix=$2
lang=data/lang${lang_suffix}_test
model=exp/chain/tdnn_1d_aug_sp
graph=exp/chain/tdnn_1d_aug_sp/graph${lang_suffix}
output_dir=exp/chain/nnet_online${lang_suffix}
bash steps/online/nnet3/prepare_online_decoding.sh --add-pitch true $lang exp/nnet3/extractor $model $output_dir
tmp_dir=server_tmp
rm -rf $tmp_dir
mkdir -p $tmp_dir
cp -r $output_dir $tmp_dir/model
cp -r $graph $tmp_dir/graph
echo $PWD
for conf in $tmp_dir/model/conf/*.conf;
do
  sed -i "s|$PWD/${output_dir}|model|g" $conf
done
cd $tmp_dir
tar -rv -f $1 model
tar -rv -f $1 graph
