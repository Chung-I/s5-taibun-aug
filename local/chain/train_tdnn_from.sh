set -e

# configs for 'chain'
affix=1d

stage=0
train_stage=-10
get_egs_stage=-10
dir=exp/chain/tdnn  # Note: _sp will get added to this
decode_iter=

# Augmentation options
aug_list="reverb babble music noise clean" # Original train dir is referred to as `clean`
num_reverb_copies=1
use_ivectors=true

# training options
num_epochs=6
initial_effective_lrate=0.00025
final_effective_lrate=0.000025
max_param_change=2.0
final_layer_normalize_target=0.5
num_cpu_jobs=12
num_jobs_initial=3
num_jobs_final=7
minibatch_size=64
frames_per_eg=150,110,90
remove_egs=false
common_egs_dir=
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'
#test_sets="eval test test_pts test_pts_merged"
test_sets="test_pts_merged"

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

# The iVector-extraction and feature-dumping parts are the same as the standard
# nnet3 setup, and you can skip them by setting "--stage 8" if you have already
# run those things.

from_dir=${dir}${affix:+_$affix}_aug_sp
dir=${dir}${affix:+_$affix}_aug_sp_ftv_cur
train_set=train_aug_sp_ftv_cur
ali_dir=exp/tri5a_aug_sp_ftv_cur_ali
lat_dir=exp/tri5a_aug_sp_ftv_cur_lats
treedir=exp/chain/tri6a_tree_aug_sp
lang=data/lang_chain

if [ $stage -le 11 ]; then
  mkdir -p $dir || exit 1;
  steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$decode_cmd" \
    --feat.online-ivector-dir exp/nnet3$nnet3_affix/ivectors_${train_set} \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.0 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --trainer.input-model $from_dir/final.mdl \
    --trainer.dropout-schedule $dropout_schedule \
    --trainer.add-option="--optimization.memory-compression-level=2" \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0 --constrained false" \
    --egs.chunk-width $frames_per_eg \
    --trainer.num-chunk-per-minibatch $minibatch_size \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate $initial_effective_lrate \
    --trainer.optimization.final-effective-lrate $final_effective_lrate \
    --trainer.max-param-change $max_param_change \
    --cleanup.remove-egs $remove_egs \
    --feat-dir data/${train_set}_hires \
    --tree-dir $treedir \
    --lat-dir $lat_dir \
    --use-gpu wait \
    --dir $dir  || exit 1;
fi
