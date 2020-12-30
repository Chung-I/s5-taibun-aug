#!/usr/bin/env bash
# Copyright 2015-2016  Sarah Flora Juan
# Copyright 2016  Johns Hopkins University (Author: Yenda Trmal)
# Copyright 2018  Yuan-Fu Liao, National Taipei University of Technology
# Apache 2.0

source_dir=language
dict_dir=data/local/dict
rm -rf $dict_dir
mkdir -p $dict_dir

#
#
#
cat $source_dir/lexiconp.txt > $dict_dir/lexiconp.txt
echo "<SIL> 1.0 SIL"	>> $dict_dir/lexiconp.txt

for phn_file in silence_phones.txt nonsilence_phones.txt optional_silence.txt extra_questions.txt ;
do
  rm -f $dict_dir/$phn_file
  touch $dict_dir/$phn_file
done
touch $dict_dir/
cat $dict_dir/lexiconp.txt | awk '{ for(n=3;n<=NF;n++){ phones[$n] = 1; }} END{for (p in phones) print p;}'| \
  perl -e 'while(<>){ chomp($_); $phone = $_; next if ($phone eq "SIL");
    m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$1} .= "$phone "; }
    foreach $l (values %q) {print "$l\n";}
  ' | sort -k1 > $dict_dir/nonsilence_phones.txt  || exit 1;

echo SIL > $dict_dir/silence_phones.txt
echo SIL > $dict_dir/optional_silence.txt

cat $dict_dir/silence_phones.txt | awk '{printf("%s ", $1);} END{printf "\n";}' > $dict_dir/extra_questions.txt || exit 1;
cat $dict_dir/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; if($p eq "\$0"){$q{""} .= "$p ";}else{$q{$2} .= "$p ";} } } foreach $l (values %q) {print "$l\n";}' \
 >> $dict_dir/extra_questions.txt || exit 1;

echo "Dictionary preparation succeeded"
exit 0;
