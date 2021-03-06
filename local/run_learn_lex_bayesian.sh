#! /bin/bash
#
# This script demonstrates a lexicon learning recipe, which aims to imrove
# the pronounciation of abbreviated words in the TED-LIUM lexicon. It assumes
# the model exp/tri3a already exists. Please see steps/dict/learn_lexicon_bayesian.sh
# for explanation of the options. 
#
# Copyright 2016  Xiaohui Zhang
# Apache 2.0

. ./cmd.sh
. ./path.sh

oov_symbol="<SIL>"
# The user may have an English g2p model ready.
g2p_mdl_dir=
# The dir which contains the reference lexicon (most probably hand-derived)
# we want to expand/improve, and nonsilence_phones.txt,.etc which we need  
# for building new dict dirs.
ref_dict=data/local/dict
# acoustic training data we use to get alternative
# pronunciations and collet acoustic evidence.
data=data/train
# the cut-off parameter used to select pronunciation candidates from phone
# decoding. We remove pronunciations with probabilities less than this value
# after normalizing the probs s.t. the max-prob is 1.0 for each word."
min_prob=0.4
# Mean of priors (summing up to 1) assigned to three exclusive pronunciation
# source: reference lexicon, g2p, and phone decoding (used in the Bayesian
# pronunciation selection procedure). We recommend setting a larger prior
# mean for the reference lexicon, e.g. '0.6,0.2,0.2'.
prior_mean="0.7,0.2,0.1"        
# Total amount of prior counts we add to all pronunciation candidates of
# each word. By multiplying it with the prior mean of a source, and then dividing
# by the number of candidates (for a word) from this source, we get the
# prior counts we actually add to each candidate.
prior_counts_tot=15
# In the Bayesian pronunciation selection procedure, for each word, we
# choose candidates (from all three sources) with highest posteriors
# until the total prob mass hit this amount.
# It's used in a similar fashion when we apply G2P.
variants_prob_mass=0.6
# In the Bayesian pronunciation selection procedure, for each word,
# after the total prob mass of selected candidates hit variants-prob-mass,
# we continue to pick up reference candidates with highest posteriors
# until the total prob mass hit this amount (must >= variants_prob_mass).
variants_prob_mass_ref=0.95
# Intermediate outputs of the lexicon learning stage will be put into dir
src_mdl_dir=exp/chain/tdnn_1d_aug_sp
lang_affix=_mandarin
dir=exp/chain/tdnn_1d_aug_sp_lex_work
g2p_lexicon_path=
ref_lang=
nj=10
decode_nj=10
stage=1
lexlearn_stage=0
test_set="test eval"

. utils/parse_options.sh # accept options


echo $oov_symbol
# The reference vocab is the list of words which we already have hand-derived pronunciations.
ref_vocab=data/local/vocab${lang_affix}.txt
cat $ref_dict/lexicon.txt | awk '{print $1}' | sort | uniq > $ref_vocab || exit 1; 

# Get a G2P generated lexicon for oov words (w.r.t the reference lexicon)
# in acoustic training data.
if [ $stage -le 0 ]; then
  if [ -z $g2p_mdl_dir ]; then
    g2p_mdl_dir=exp/g2p
    steps/dict/train_g2p.sh --cmd "$decode_cmd --mem 4G" $ref_dict/lexicon.txt $g2p_mdl_dir || exit 1;
  fi
  awk '{for (n=2;n<=NF;n++) vocab[$n]=1;} END{for (w in vocab) printf "%s\n",w;}' \
    $data/text | sort -u > $data/train_vocab.txt || exit 1;
  awk 'NR==FNR{a[$1] = 1; next} {if(!($1 in a)) print $1}' $ref_vocab \
    $data/train_vocab.txt | sort > $data/oov_train.txt || exit 1;
  steps/dict/apply_g2p.sh --var-counts 4 $data/oov_train.txt \
    $g2p_mdl_dir exp/g2p/oov_lex_train || exit 1;
  cat exp/g2p/oov_lex_train/lexicon.lex | awk '{if (NF>=3) print $0}' | cut -f1,3 | \
    tr -s '\t' ' ' | sort | uniq > $data/lexicon_oov_g2p.txt || exit 1;
fi

# Learn a lexicon based on the acoustic training data and the reference lexicon.
if [ $stage -le 1 ]; then
  #cat $g2p_lexicon_path | awk '{if (NF>=3) print $0}' | cut -d ' ' -f1,3- | \
  #  sort | uniq > $data/lexicon_oov_g2p.txt || exit 1;
  #cp $g2p_lexicon_path $dir/lexiconp_g2p.txt
  steps/dict/learn_lexicon_bayesian_nnet.sh --lexiconp-g2p $g2p_lexicon_path \
    --min-prob $min_prob --variants-prob-mass $variants_prob_mass \
    --variants-prob-mass-ref $variants_prob_mass_ref  \
    --prior-counts-tot $prior_counts_tot --prior-mean $prior_mean \
    --stage $lexlearn_stage --nj $nj --oov-symbol $oov_symbol --retrain-src-mdl false \
    $ref_dict $ref_vocab $data $src_mdl_dir $ref_lang data/local/dict_learned_nosp${lang_affix} \
    $dir || exit 1;
fi

# Add pronounciation probs to the learned lexicon.
#if [ $stage -le 1 ]; then
#  utils/prepare_lang.sh --phone-symbol-table data/lang/phones.txt \
#    data/local/dict_learned_nosp${lang_affix} $oov_symbol \
#    data/local/lang_learned_nosp${lang_affix} data/lang_learned_nosp${lang_affix} || exit 1;
#  
#  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
#    $data data/lang_learned_nosp exp/tri2 exp/tri2_ali_learned_lex_nosp || exit 1;
#  
#  steps/get_prons.sh --cmd "$train_cmd" data/train data/lang_learned_nosp exp/tri2_ali_learned_lex_nosp || exit 1;
#  
#  utils/dict_dir_add_pronprobs.sh --max-normalize true \
#    data/local/dict_learned_nosp exp/tri2_ali_learned_lex_nosp/pron_counts_nowb.txt \
#    exp/tri2_ali_learned_lex_nosp/sil_counts_nowb.txt \
#    exp/tri2_ali_learned_lex_nosp/pron_bigram_counts_nowb.txt data/local/dict_learned || exit 1;
#  
#  utils/prepare_lang.sh --phone-symbol-table data/lang/phones.txt \
#    data/local/dict_learned $oov_symbol data/local/lang_learned data/lang_learned || exit 1;
#fi
#
## Re-train the acoustic model using the learned lexicon
#if [ $stage -le 2 ]; then
#  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
#    $data data/lang_learned exp/tri3a exp/tri3a_ali_learned_lex || exit 1;
#  
#  steps/train_sat.sh --cmd "$train_cmd" \
#    5000 100000 $data data/lang_learned exp/tri3a_ali_learned_lex exp/tri3a_learned_lex || exit 1;
#fi
#
## Decode
#if [ $stage -le 3 ]; then
#  cp -rT data/lang_learned data/lang_learned_rescore || exit 1;
#  ! cmp data/lang_nosp/words.txt data/lang_learned/words.txt &&\
#    echo "$0: The vocab of the learned lexicon and the reference vocab may be incompatible."
#  cp data/lang_nosp/G.fst data/lang_learned/
#  cp data/lang_nosp_rescore/G.carpa data/lang_learned_rescore/
#  utils/mkgraph.sh data/lang_learned exp/tri3a_learned_lex exp/tri3a_learned_lex/graph || exit 1;
#  
#  for dset in $testsets; do
#    steps/decode_fmllr.sh --nj $decode_nj --cmd "$decode_cmd"  --num-threads 4 \
#     exp/tri3a_learned_lex/graph data/${dset} exp/tri3a_learned_lex/decode_${dset} || exit 1;
#    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" data/lang_learned data/lang_learned_rescore \
#      data/${dset} exp/tri3a_learned_lex/decode_${dset} exp/tri3a_learned_lex/decode_${dset}_rescore || exit 1;
#  done
#fi

wait
