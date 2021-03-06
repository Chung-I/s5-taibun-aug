
set -eo pipefail

train_set=ftv
nj=12

. ./cmd.sh
. ./utils/parse_options.sh
. ./path.sh

#local/prepare_ftv_data.sh --train-num 1 --data-dir data/great_times
#local/prepare_ftv_data.sh --train-num 2 --data-dir data/dowry
#local/prepare_ftv_data.sh --train-num 3 --data-dir data/happiness
#utils/data/combine_data.sh data/$train_set data/great_times data/dowry data/happiness || exit 1;

#steps/make_mfcc_pitch.sh --cmd "$train_cmd" --nj 70 data/$train_set \
#  exp/make_mfcc/$train_set mfcc || exit 1;
#steps/compute_cmvn_stats.sh data/$train_set exp/make_mfcc/$train_set mfcc || exit 1;
#utils/fix_data_dir.sh data/$train_set || exit 1;


#steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" --stage 1 data/$train_set \
#  data/lang_mandarin exp/tri5a exp/tri5a_ftv_lats
#rm exp/tri5a_ftv_lats/fsts.*.gz # save space
srcdir=exp/tri5a_ftv_lats
dir=exp/tri5a_ftv_ali
acoustic_scale=0.1
mkdir -p $dir
cmd=run.pl
$cmd JOB=1:$nj $srcdir/log/generate_alignments.JOB.log \
  lattice-best-path --acoustic-scale=$acoustic_scale "ark:gunzip -c $srcdir/lat.JOB.gz |" \
  ark:/dev/null "ark:|gzip -c >$dir/ali.JOB.gz" || exit 1;
