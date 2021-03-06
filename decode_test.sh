. cmd.sh
. path.sh

stage=-1

. ./utils/parse_options.sh

if [ $stage -le -1 ]; then
  #local/prepare_test_data.sh --train-dir FSR-2020_final-test_chinese --data-dir data/final_test_chinese
  local/prepare_test_data.sh --train-dir FSR-2020_final-test_taibun --data-dir data/final_test_taibun
  local/prepare_test_data.sh --train-dir FSR-2020_final-test_tailo --data-dir data/final_test_tailo
fi

#testsets="final_test_chinese final_test_taibun"

if [ $stage -le 0 ]; then
  testsets="final_test_taibun final_test_tailo"
  for test_set in $testsets;
  do
    bash decode_taibun.sh --dir exp/chain/tdnn_1d_aug_sp_ftv_ivector --stage 1 --test-set $test_set --num-jobs 12 --skip-scoring true --extract-features false
  done
  exit 0;
fi

if [ $stage -le 1 ]; then
  testsets="final_test_chinese "
  for test_set in $testsets;
  do
    bash decode_mandarin.sh --dir exp/chain/tdnn_1d_aug_sp_ftv_ivector --stage -2 --testset-root $test_set --num-jobs 12 --skip-scoring true 
  done
fi
