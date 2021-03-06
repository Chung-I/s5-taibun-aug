
. ./path.sh
. ./cmd.sh

datasets="pts_tw_extra_mandarin abula_big"
num_utts=5000
infix=5k
combined_dataset="test_mandarin_10k"

. ./utils/parse_options.sh || exit 1;


hires_data_dirs=""
data_dirs=""

for dataset in $datasets;
do
  subset_data_dir=${dataset}_${infix}
  utils/subset_data_dir.sh data/${dataset}_hires $num_utts data/${subset_data_dir}_hires
  hires_data_dirs="$hires_data_dirs data/${subset_data_dir}_hires"
  utils/subset_data_dir.sh --utt-list data/${subset_data_dir}_hires/utt2spk data/${dataset} data/${subset_data_dir}
  data_dirs="$data_dirs ${subset_data_dir}"
done

utils/combine_data.sh data/${combined_dataset} $data_dirs
utils/combine_data.sh data/${combined_dataset}_hires $hires_data_dirs
