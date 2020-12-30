. ./path.sh
dir=exp/tri3a_lex_work
cmd=run.pl
min_prob=0.4
$cmd $dir/phonetic_decoding/log/prons_to_lexicon.log steps/dict/prons_to_lexicon.py \
    --min-prob=$min_prob --filter-lexicon=$dir/phonetic_decoding/filter_lexicon.txt \
    $dir/phonetic_decoding/prons.txt $dir/lexicon_phonetic_decoding_with_eps.txt
  cat $dir/lexicon_phonetic_decoding_with_eps.txt | grep -vP "<eps>|<UNK>|<unk>|\[.*\]" | \
    sort | uniq > $dir/lexicon_phonetic_decoding.txt || exit 1;
