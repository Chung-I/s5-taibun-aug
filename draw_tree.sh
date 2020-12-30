set -eo pipefail
. ./path.sh

draw-tree data/lang/phones.txt exp/tri5a/tree | dot -Gsize="100,100"  -Tps | ps2pdf - tree.pdf
