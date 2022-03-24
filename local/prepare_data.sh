#!/usr/bin/env bash
# Copyright 2015-2016  Sarah Flora Juan
# Copyright 2016  Johns Hopkins University (Author: Yenda Trmal)
# Copyright 2018  Yuan-Fu Liao, National Taipei University of Technology
#                 AsusTek Computer Inc. (Author: Alex Hung)

# Apache 2.0

set -e -o pipefail

train_dir=condenser/wav
data_dir=data/tat

. ./path.sh
. parse_options.sh

for x in $train_dir; do
  if [ ! -d "$x" ] ; then
    echo >&2 "The directory $x does not exist"
  fi
done

if [ -z "$(command -v dos2unix 2>/dev/null)" ]; then
    echo "dos2unix not found on PATH. Please insttat it manutaty."
    exit 1;
fi

# have to remove previous files to avoid filtering speakers according to cmvn.scp and feats.scp
rm -rf   $data_dir
mkdir -p $data_dir


# make utt2spk, wav.scp and text
echo "prepare text"
python3 text_prepare_tailo.py condenser/json
mv text $data_dir/text

mkdir -p tmp
cat $data_dir/text | awk '{print $1}' > tmp/utt
cat $data_dir/text | awk '$1=""; {print $0}' | sed 's/^\s\+//' > tmp/only_text
python3 dict_seg.py $lexicon_path tmp/only_text tmp/only_seg_text
paste -d " " tmp/utt tmp/only_seg_text | grep -Ev 'unsegmentable' > $data_dir/text
rm -rf tmp

echo "prepare utt2spk"
find -L $train_dir -name *.wav -exec sh -c 'x={}; y=$(basename -s .wav $x); z=$(echo "$x" |cut -d / -f 3); printf "%s_%s %s\n" $z $y $z' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/utt2spk
echo "prepare wav.scp"
find -L $train_dir -name *.wav -exec sh -c 'x={}; y=$(basename -s .wav $x); z=$(echo "$x" |cut -d / -f 3); printf "%s_%s %s\n" $z $y $x' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/wav.scp

# fix_data_dir.sh fixes common mistakes (unsorted entries in wav.scp,
# duplicate entries and so on). Also, it regenerates the spk2utt from
# utt2spk
utils/fix_data_dir.sh $data_dir


echo "Data preparation completed."
exit 0;
