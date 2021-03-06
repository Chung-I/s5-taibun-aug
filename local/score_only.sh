#!/usr/bin/env bash

set -e -o pipefail
set -x
steps/score_kaldi.sh --stage 0 "$@"
steps/scoring/score_kaldi_cer.sh --stage 0 "$@"

echo "$0: Done"
