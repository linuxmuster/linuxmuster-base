#!/usr/bin/perl

use Env::Bash;

sub ReadDistConf {
  my $distconf = "/usr/share/linuxmuster/config/dist.conf";
  my %env = ();

  tie %env, "Env::Bash", Source => "$distconf", ForceArray => 1;
  while( my( $key, $value ) = each %env ) {
    $$key = "@$value";
  }

  tie %env, "Env::Bash", Source => "$NETWORKSETTINGS", ForceArray => 1;
  while( my( $key, $value ) = each %env ) {
    $$key = "@$value";
  }

}

sub ReadWorkstationData {
  my $wsdatafile = shift;
  my @workstation;
  my @tmparray;
  open(WIMPORTDATA, $wsdatafile) || die "Cannot open $wsdatafile: $!";
  # read workstation data file
  while(<WIMPORTDATA>) {

    # ignore empty lines
    next if (length($_)<2);
    # ignore comments
    next if (/^#/);
    $_ =~ s/\s*//;

    chomp;
    my($room, $hostname, $hwclass, $macaddress, $ip, $netmask, $part1, $part2, $part3, $part4, $pxe, $rembo_opts) = split(/\s*[;\n]\s*/, $_);
    # change order of array that it can be sorted by hwclass later
    push(@tmparray, "$hwclass;$room;$hostname;$macaddress;$ip;$netmask;$part1;$part2;$part3;$part4;$pxe;$rembo_opts");
  }
  close WIMPORTDATA;
  # now sort by hwclass
  @tmparray = sort @tmparray;
  
  # now push workstation variables into hashes and return the whole array
  foreach (@tmparray) {
    # read in fields into variables
    my($hwclass, $room, $hostname, $macaddress, $ip, $netmask, $part1, $part2, $part3, $part4, $pxe, $rembo_opts) = split(/\s*[;\n]\s*/, $_);
    # add workstation to array
    push(@workstation, {
      hwclass        => $hwclass,
      room           => $room,
      hostname       => $hostname,
      macaddress     => $macaddress,
      ip             => $ip,
      netmask        => $netmask,
      part1          => $part1,
      part2          => $part2,
      part3          => $part3,
      part4          => $part4,
      pxe            => $pxe,
      rembo_opts     => $rembo_opts
    });
  }
  return (@workstation);
}

sub db_get {
  my $db_var = shift;
  my $ret = `echo get $db_var | debconf-communicate`;
  substr($ret, 0, 2) = "";
  $ret =~ s/^\s+//;
  $ret =~ s/\s+$//;
  return $ret;
}

return 1;
