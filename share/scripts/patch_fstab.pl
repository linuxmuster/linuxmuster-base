#!/usr/bin/perl 
#--------------------------------------------------------------------------  
# patches fstab on stage 1 install
# don't call this script manual!

my $userfile = "/etc/fstab";
my $userfiletmp = "$userfile.tmp";
my $line;

my $FOUND = 0;
my $FOUNDTMP = 0;
my $FOUNDHOME = 0;
my $FOUNDVAR = 0;


open (FSTAB, "<$userfile") or die "cannot open user file $userfile: $!";
open (FSTABTMP, ">$userfiletmp") or die "cannot open user file $userfiletmp: $!";


while ($line = <FSTAB>){

  chomp($line);

  my($part, $mpoint, $type, $options, $dump, $pass) = split(" ", $line, 6);

  if ( $mpoint eq "/home" ) {

    $options = "defaults,usrquota,grpquota";
    $FOUND = 1;
    $FOUNDHOME = 1;

  }

  if ( $mpoint eq "/var" ) {

    $options = "defaults,noatime,usrquota,grpquota";
    $FOUND = 1;
    $FOUNDVAR = 1;

  }

  if ( $mpoint eq "/tmp" ) {

    $FOUNDTMP = 1;

  }

  if ( $FOUND == 0 ) {

    print FSTABTMP "$line\n";

  } else {

    print FSTABTMP "$part\t$mpoint\t$type\t$options\t$dump\t$pass\n";
    $FOUND = 0;

  }

}


if ( $FOUNDTMP == 0 ) {

  print FSTABTMP "none\t/tmp\ttmpfs\tdefaults\t0\t0\n";

}


close FSTAB;
close FSTABTMP;

`mv -f $userfiletmp $userfile`;


# root has to be quoted if no /var or /home has been found
if ( $FOUNDVAR == 0 || $FOUNDHOME == 0 ) {

  $FOUND = 0;

  open (FSTAB, "<$userfile") or die "cannot open user file $userfile: $!";
  open (FSTABTMP, ">$userfiletmp") or die "cannot open user file $userfiletmp: $!";

  while ($line = <FSTAB>){

    chomp($line);

    my($part, $mpoint, $type, $options, $dump, $pass) = split(" ", $line, 6);

    if ( $mpoint eq "/" ) {

      $options = "defaults,errors=remount-ro,usrquota,grpquota";
      $FOUND = 1;

    }

    if ( $FOUND == 0 ) {

      print FSTABTMP "$line\n";

    } else {

      print FSTABTMP "$part\t$mpoint\t$type\t$options\t$dump\t$pass\n";
      $FOUND = 0;

    }

  }

  close FSTAB;
  close FSTABTMP;

  `mv -f $userfiletmp $userfile`;

}

