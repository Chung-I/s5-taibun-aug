#bash utils/combine_data.sh data/train_aug_sp_ftv data/train_aug_sp data/ftv
#bash utils/combine_data.sh data/train_aug_sp_ftv_hires data/train_aug_sp_hires data/ftv_hires
#cp exp/tri5a_aug_sp_lats/tree exp/tri5a_ftv_lats
#cp exp/tri5a_aug_sp_lats/phones.txt exp/tri5a_ftv_lats
#cp exp/tri5a_aug_sp_ali/tree exp/tri5a_ftv_ali
#cp exp/tri5a_aug_sp_ali/phones.txt exp/tri5a_ftv_ali
cp exp/tri5a_aug_sp_ali/num_jobs exp/tri5a_ftv_ali
#bash steps/combine_lat_dirs.sh --nj 12 data/train_aug_sp_ftv exp/tri5a_aug_sp_ftv_lats exp/tri5a_aug_sp_lats exp/tri5a_ftv_lats
bash steps/combine_ali_dirs.sh --nj 12 data/train_aug_sp_ftv exp/tri5a_aug_sp_ftv_ali exp/tri5a_aug_sp_ali exp/tri5a_ftv_ali
mkdir -p exp/nnet3/ivectors_train_aug_sp_ftv
cat exp/nnet3/ivectors_train_aug_sp/ivector_online.scp exp/nnet3/ivectors_ftv/ivector_online.scp | sort -k1 > exp/nnet3/ivectors_train_aug_sp_ftv/ivector_online.scp
cp exp/nnet3/ivectors_train_aug_sp/final.ie.id exp/nnet3/ivectors_train_aug_sp_ftv 
cp exp/nnet3/ivectors_train_aug_sp/ivector_period exp/nnet3/ivectors_train_aug_sp_ftv 
