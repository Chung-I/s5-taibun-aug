order=3
stage=0
discount_type="wbdiscount"
lm_type="srilm"

. ./path.sh
. ./cmd.sh

. ./utils/parse_options.sh

text=$1
vocab=$2
dest_file=$3

echo "lm_output: $dest_file"

if [ $stage -le 0 ];
then
  if [ $lm_type == "srilm" ];
  then
    discount_opts=""
    for disc in $(seq 1 $order);
    do
      discount_opts="$discount_opts -${discount_type}${disc}"
    done
    
    echo $wbdiscount_opts
    ngram-count -text $text $discount_opts -vocab ${vocab} -order $order -sort -tolower -lm $dest_file
  elif [ $lm_type == "kenlm" ];
  then
    lmplz -o $order < $text --limit_vocab_file $vocab > $dest_file
  else
    echo "no such lm_type: $lm_type; exiting ..." && exit 1;
  fi
fi

