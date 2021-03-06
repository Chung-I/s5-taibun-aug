order=3
stage=0

. ./path.sh
. ./cmd.sh

. ./utils/parse_options.sh

arpas="$1"
dest_file="$2"

if [ $stage -le 1 ] ;
then
  lm_weights=""
  num_files="$(echo $arpas | wc -w)"
  weight=$(python3 -c "print(1.0/$num_files)")
  for text in $arpas;
  do
    echo $text
    lm_weights="$lm_weights $weight"
  done
  
  if [ $# -gt 2 ]; then
    weights="$3"
  else
    weights="$lm_weights"
  fi
  
  echo $arpas
  echo $dest_file
  mkdir -p $(dirname $dest_file)
  python3 run_interp_lm.py --lms $arpas --weights $weights --order $order --out-lm $dest_file
fi
