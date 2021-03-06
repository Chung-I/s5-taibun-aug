for test_set in test_pts_merged pilot ;
do
  bash decode_taibun.sh --dir exp/chain/tdnn_1d_aug_sp_ftv --stage 1 --test-set $test_set
done

for test_set in pilot ;
do
  bash decode_mandarin.sh --dir exp/chain/tdnn_1d_aug_sp_ftv --stage 1 --testset-root $test_set --num-jobs 12
done
