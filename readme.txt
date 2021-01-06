data augmentation needs musan (http://www.openslr.org/17/).
set $CORPUS_DIR in path.sh and put musan under $CORPUS_DIR. (see local/nnet3/run_aug.sh).
reverberation needs RIRS_NOISES (https://www.openslr.org/28/).
put RIRS_NOISES here. (see local/nnet3/run_aug.sh)

python package requirements:
ckiptagger
regex
zhon
cn2an
opencc

to prepare PTS_TW-extra data, run:
mandarin:
local/prepare_pts_data.sh --train-dir PTS_TW-extra --data-dir data/<dataset_name> --add-parent-prefix true \
  --lexicon-path language/mandarin_phn_lexiconp.txt --txtdir mandarin_text

taibun:
local/prepare_pts_data.sh --train-dir PTS_TW-extra --data-dir data/<dataset_name> --add-parent-prefix true \
  --lexicon-path language/hanlo_tailo_phn_lexiconp.txt --txtdir taibun_text

上次的PTS_TW-extra的text是mandarin跟taibun在同一個檔案裡，
這次給的PTS_TW-extra-textonly只是把它分開來成taibun_text跟mandarin_text，作為--txtdir的參數

