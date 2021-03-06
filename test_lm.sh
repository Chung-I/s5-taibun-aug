order=3

. ./path.sh
. ./cmd.sh

. ./utils/parse_options.sh

lm_file=$1
test_text=$2
ppl_file=$3

ngram -lm $lm_file -order $order -ppl ${test_text} -debug 2 > $ppl_file
