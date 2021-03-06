#!/usr/bin/env bash
# Copyright 2015-2016  Sarah Flora Juan
# Copyright 2016  Johns Hopkins University (Author: Yenda Trmal)
# Copyright 2018  Yuan-Fu Liao, National Taipei University of Technology
#                 AsusTek Computer Inc. (Author: Alex Hung)

# Apache 2.0

set -e -o pipefail

train_dir=PTS_TW-train
data_dir=data/pts
add_parent_prefix=false
lexicon_path=language/lexiconp.txt
txtdir=text

. ./path.sh
. parse_options.sh

for x in $train_dir; do
  if [ ! -d "$x" ] ; then
    echo >&2 "The directory $x does not exist"
  fi
done

if [ -z "$(command -v dos2unix 2>/dev/null)" ]; then
    echo "dos2unix not found on PATH. Please instpts it manuptsy."
    exit 1;
fi

# have to remove previous files to avoid filtering speakers according to cmvn.scp and feats.scp
#mkdir -p $data_dir $data_dir1 data/train data/test data/eval data/local/train
rm -rf $data_dir
mkdir -p $data_dir


make_pts_text_opts=
if [ $add_parent_prefix == "true" ]; then
  make_pts_text_opts="$make_pts_text_opts --add-parent-prefix"
fi
echo $make_pts_text_opts
# make utt2spk, wav.scp and text
echo "prepare text"
mkdir -p tmp
python3 local/make_pts_text.py $train_dir/$txtdir $data_dir $make_pts_text_opts
cat $data_dir/text | awk '{print $1}' > tmp/utt
cat $data_dir/text | awk '$1=""; {print $0}' | sed 's/^\s\+//' > tmp/only_text
python3 dict_seg.py $lexicon_path tmp/only_text tmp/only_seg_text --with-prob --form sent --ckip-path /home/nlpmaster/ssd-1t/weights/data --lower --non-hanzi-in-lexicon
paste -d " " tmp/utt tmp/only_seg_text | grep -Ev 'unsegmentable' > $data_dir/text
rm -r tmp

if [ $add_parent_prefix == "true" ]; then
  find -L $train_dir/wav -name *.wav -exec sh -c 'x={}; y=$(basename -s .wav $x); z=$(echo $x | rev | cut -d '/' -f2 | rev); printf "%s-%s %s\n" $z $y $x' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/wav.scp
else
  find -L $train_dir/wav -name *.wav -exec sh -c 'x={}; y=$(basename -s .wav $x); printf "%s %s\n" $y $x' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/wav.scp
fi

cat $data_dir/text | awk '{print $1,$1}' > $data_dir/utt2spk

#cat $eval_dir/refs.txt | awk -F '/' 'BEGIN { OFS = "-" } {print $1, $3}' | sed 's/\.wav//g' > tmp/eval_utt
#paste tmp/eval_utt $eval_dir/trn.txt > data/eval/text
#cat $eval_dir/refs.txt | sed -e "s|^|${eval_dir}/|" > tmp/refs.txt
#paste tmp/eval_utt tmp/refs.txt > data/eval/wav.scp
#paste tmp/eval_utt tmp/eval_utt > data/eval/utt2spk
##find -L $train_dir -name *.wav -exec sh -c 'x={}; y=$(basename -s .wav $x); z=$(echo "$x" |cut -d / -f 3); printf "%s_%s %s\n" $z $y $z' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/utt2spk
##find -L $train_dir -name *.wav -exec sh -c 'x={}; y=$(basename -s .wav $x); z=$(echo "$x" |cut -d / -f 3); printf "%s_%s %s\n" $z $y $x' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/wav.scp
#
## fix_data_dir.sh fixes common mistakes (unsorted entries in wav.scp,
## duplicate entries and so on). Also, it regenerates the spk2utt from
## utt2spk
utils/fix_data_dir.sh $data_dir
#
#echo "Preparing train,eval and test data"
## eval set:IU_IUF0008 IU_IUM0012 KK_KKM0001 KH_KHF0008 IU_IUF0005 TS_TSF0017 IU_IUM0009 KK_KKM0006
##grep -E "(IU_IUF0008|IU_IUM0012|KK_KKM0001|KH_KHF0008|IU_IUF0005|TS_TSF0017|IU_IUM0009|KK_KKM0006)" $data_dir/utt2spk | awk '{print $2}' > $data_dir/cv1.spk
##utils/subset_data_dir_tr_cv.sh --cv-spk-list $data_dir/cv1.spk $data_dir $data_dir1 data/eval
## test set:TA_TAM0001 IU_IUF0013 KH_KHF0003 IU_IUM0014 TH_THF0021 TH_THM0011 TH_THF0005 KK_KKF0013
#utils/subset_data_dir.sh data/test_full 2000 data/test || exit 1;



echo "Data preparation completed."
exit 0;
