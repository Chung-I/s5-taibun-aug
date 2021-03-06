f=$1
fout=$2
cat $f |  perl -CSDA -ane '
  {
    print $F[0];
    foreach $s (@F[1..$#F]) {
      if (($s =~ /\[.*\]/) || ($s =~ /\<.*\>/) || ($s =~ "!SIL")) {
        print " $s";
      } else {
        @chars = split "", $s;
        foreach $c (@chars) {
          print " $c";
        }
      }
    }
    print "\n";
  }' > $fout
