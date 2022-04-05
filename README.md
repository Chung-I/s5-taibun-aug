# s5-taibun-aug
## Usage
1. Install Kaldi, and modify kaldi root in ```path.sh```
   ```
   export KALDI_ROOT=YOUR_KALDI_ROOT
   ```
2. Data augmentation needs musan (http://www.openslr.org/17/). Set $CORPUS_DIR in path.sh and put musan in $CORPUS_DIR. See ```local/nnet3/run_aug.sh``` for more details.
    ```
    export CORPUS_DIR=YOUR_MUSAN_DIR
    ```
3. Reverberation needs RIRS_NOISES (https://www.openslr.org/28/). Download the data from the website, rename the directory to ```RIRS_NOISES```, and
put ```RIRS_NOISES``` in the root (```s5-taibun-aug/```). See ```local/nnet3/run_aug.sh``` for more details.

4.
    a. (For NTU Speech Lab) Put ```PTS_TW-train``` in the root. A more efficient way:
    ```
    ln -s /groups/public/PTS_TW-train .
    ```
    b. (For other users) To prepare PTS_TW-extra data, run:

        i. mandarin:
        ```
        local/prepare_pts_data.sh --train-dir PTS_TW-extra --data-dir data/<dataset_name> --add-parent-prefix true \
        --lexicon-path language/mandarin_phn_lexiconp.txt --txtdir mandarin_text
        ```
        ii. taibun:
        ```
        local/prepare_pts_data.sh --train-dir PTS_TW-extra --data-dir data/<dataset_name> --add-parent-prefix true \
        --lexicon-path language/hanlo_tailo_phn_lexiconp.txt --txtdir taibun_text
        ```
5. The script is currently for computers with 2 GPU, to adjust for more / less GPUs, modify

    a. ```local/chain/run_tdnn.sh```
    ```
    num_jobs_initial=2
    num_jobs_final=2
    ```
    [It is suggested](https://groups.google.com/g/kaldi-help/c/63L4dJRPGQs/m/51Qyf6McBgAJ) that the ```num_jobs_initial``` and the ```num_jobs_final``` not greater than the number of GPUs you have. These two parameters can affect the model performance and could be fine-tuned with ```num_epochs``` for better accuracy.

    b. ```local/nnet3/run_ivector_aug_common.sh```

    modify ```nj``` in
    ```
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 2
    ```
    

## Requirements
python package requirements:
    - ckiptagger
    - regex
    - zhon
    - cn2an
    - opencc

