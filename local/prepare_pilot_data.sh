#!/usr/bin/env bash
# Copyright 2015-2016  Sarah Flora Juan
# Copyright 2016  Johns Hopkins University (Author: Yenda Trmal)
# Copyright 2018  Yuan-Fu Liao, National Taipei University of Technology
#                 AsusTek Computer Inc. (Author: Alex Hung)

# Apache 2.0

set -e -o pipefail

raw_data_dir=raw_pilot
data_dir=data/pilot

. ./path.sh
. parse_options.sh

for x in $raw_data_dir; do
  if [ ! -d "$x" ] ; then
    echo >&2 "The directory $x does not exist"
  fi
done

if [ -z "$(command -v dos2unix 2>/dev/null)" ]; then
    echo "dos2unix not found on PATH. Please install it manually."
    exit 1;
fi

# have to remove previous files to avoid filtering speakers according to cmvn.scp and feats.scp
rm -rf   $data_dir
mkdir -p $data_dir

# make utt2spk, wav.scp and text
echo "prepare text"
python3 text_prepare_tailo.py $raw_data_dir/json --test-set --corpus-prefix pilot
mv text $data_dir/text

#mkdir -p tmp
#cat $data_dir/text | awk '{print $1}' > tmp/utt
#cat $data_dir/text | awk '$1=""; {print $0}' | sed 's/^\s\+//' > tmp/only_text
#python3 dict_seg.py language/lexicon_taibun.txt tmp/only_text tmp/only_seg_text --with-prob --form sent
#paste -d " " tmp/utt tmp/only_seg_text | grep -Ev 'unsegmentable' > $data_dir/text

echo "prepare utt2spk"
find -L $raw_data_dir/wav -name '*.wav' -exec sh -c 'x={}; y=$(basename -s .wav $x); printf "pilot-%s pilot-%s\n" $y $y' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/utt2spk
echo "prepare wav.scp"
find -L $raw_data_dir/wav -name '*.wav' -exec sh -c 'x={}; y=$(basename -s .wav $x); printf "pilot-%s %s\n" $y $x' \; | sed 's/\xe3\x80\x80\|\xc2\xa0//g' | dos2unix > $data_dir/wav.scp

# fix_data_dir.sh fixes common mistakes (unsorted entries in wav.scp,
# duplicate entries and so on). Also, it regenerates the spk2utt from
# utt2spk
utils/fix_data_dir.sh $data_dir

echo "Data preparation completed."
exit 0;
