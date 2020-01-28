#!/usr/bin/perl

# Note:
#   This work has been done during my time at Gradual
# 
# -- Copyright GCM, 2016,2017 --
# 


package DVS;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

if (! exists $ENV{TZ}) {
my %time_zones = (
   EST => '-0500',
   PST => '-0800',
   PDT => '-0700',
);
   $ENV{'TZ'} = 'B'; # Bravo time zone UTC+2
   $ENV{'TZ'} = 'America/New_York';
   $ENV{'TZ'} = 'PST2PDT';
   $ENV{'TZ'} = 'EST'; 
   $ENV{'TZ'} = 'CET'; # Central Europe
   if (0) {
   # see [*](https://stackoverflow.com/questions/45810071/tzset-setting-tz-env-variable-doesnt-work-under-windows)
     use POSIX qw(tzset);
     tzset();
   }
}

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');

# -------------------------------------------------------------------
our $fdow = &fdow($^T);
# -----------------------------------------------------------------------
our $wordlists = {};
our $DICT = '';
    $DICT = (exists $ENV{DICT}) ? $ENV{DICT} : '../etc'; # '/usr/share/dict';

# =======================================================================
if (__FILE__ eq $0) {
#  understand variable=value on the command line...
   eval "\$$1=$2"while ($ARGV[0]||'N/A') =~ /^(\w+)=(.*)/ && shift;
   if ($dbug) {
      eval "use YAML::Syck qw(Dump);";
   }
}
# =======================================================================
sub hashr {
   my $alg = shift;
   my $rnd = shift; # number of round to run ...
   my $tmp = join('',@_);
   use Crypt::Digest qw();
   my $msg = Crypt::Digest->new($alg) or die $!;
   for (1 .. $rnd) {
      $msg->add($tmp);
      $tmp = $msg->digest();
      $msg->reset;
      #printf "#%d tmp: %s\n",$_,unpack'H*',$tmp;
   }
   return $tmp
}
# ---------------------------------------------------------------------------
sub copy ($$) {
 my ($src,$trg) = @_;
 local (*F1, *F2);
 return undef unless -r $src;
 return undef if (-e $trg && ! -w $trg);
 open F2,'>',$trg or die "-w $trg $!"; binmode(F2);
 open F1,'<',$src or warn "-r $src $!"; binmode(F1);
 local $/ = undef;
 my $tmp = <F1>; print F2 $tmp;
 close F1;

 my ($atime,$mtime,$ctime) = (lstat(F1))[8,9,10];
 #my $etime = ($mtime < $ctime) ? $mtime : $ctime;
 utime($atime,$mtime,$trg);
 close F2;
 return $?;
}
# -----------------------------------------------------
sub shake { # use shake 128
  use Crypt::Digest::SHAKE;
  my $len = shift;
  my $x = ($len >= 160) ? 256 : 128;
  my $msg = Crypt::Digest::SHAKE->new($x);
  $msg->add(join'',@_);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}
# -----------------------------------------------------
sub get_shake { # use shake 256 because of ipfs' minimal length of 20Bytes
  use Crypt::Digest::SHAKE;
  my $len = shift;
  local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
  #binmode F unless $_[0] =~ m/\.txt/;
  my $msg = Crypt::Digest::SHAKE->new(256);
  $msg->addfile(*F);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}
# -----------------------------------------------------
sub get_digest ($@) {
 my $alg = shift;
 my $ns = (scalar @_ == 2) ? shift : undef;
 use Digest qw();
 local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
 binmode F unless $_[0] =~ m/\.txt/;
 my $msg = Digest->new($alg) or die $!;
    $msg->add($ns) if defined $ns;
    $msg->addfile(*F);
 my $digest = uc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub githash {
 use Digest::SHA1 qw();
 local *F = shift; seek(F,0,0);
 my $msg = Digest::SHA1->new() or die $!;
    $msg->add(sprintf "blob %u\0",(lstat(F))[7]);
    $msg->addfile(*F);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------------------------
sub fdow {
   my $tic = shift;
   use Time::Local qw(timelocal);
   ##     0    1     2    3    4     5     6     7
   #y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}
# -----------------------------------------------------------------------
sub version_old {
  #y ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #y $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime;
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10]; # ctime,mtime
  my $vtime = $times[-1];

  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($vtime))[0..7]; # most recent
  printf "%s/%s/%s \@ %d:%02d:%02d\n",$mday,$mon+1,$yy+1900,$hour,$min,$sec if $dbug;
  my $rweek=($yday+&fdow($vtime))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;
  #   my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #   print "y:$yday f:$fdow m:$mtime c:$ctime, $mday.$mon.$yy -> rw=$rweek $rev_id $low_id $version\n";

  if (wantarray) {
     my $md6 = &get_digest('MD6',$_[0]);
     print "$_[0] : md6:$md6\n" if $dbug;
     my $pn = hex(substr($md6,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
}
# -----------------------------------------------------------------------
sub rname { # extract rootname
  my $rname = shift;
  $rname =~ s,\\,/,g; # *nix style !
  my $s = rindex($rname,'/');
  $rname = substr($rname,$s+1);
  $rname =~ s/\.[^\.]+//;
  return $rname; 
}
# -----------------------------------------------------------------------
sub version {
  #y ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10]; # ctime,mtime
  my $vtime = $times[-1]; # biggest time...
  my $version = &rev($vtime);

  if (wantarray) {
     my $shk = &get_shake(160,$_[0]);
     print "$_[0] : shk:$shk\n" if $dbug;
     my $pn = unpack('n',substr($shk,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
}
# -----------------------------------------------------------------------
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+&fdow($_[0]))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
# -----------------------------------------------------------------------
sub stamp36 {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $_1yr = 365.25 * 24;
  my $yhour = $yday * 24 + $hour + ($min / 60 + $sec / 3600);
  my $stamp = &base36(int($yhour/$_1yr * 36**4)); # 18 sec accuracy
  #print "$yy/$mon/$mday $hour:$min:$sec : $yday HH$yhour\n";
  return $stamp;
}
# -----------------------------------------------------------------------
sub etime {
  my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime; # pick the earliest
  my $ltime = ($ctime > $mtime) ? $ctime : $mtime; # latest of the two
  return (wantarray) ? ($etime,$ltime) : $etime;
}
# -----------------------------------------------------------------------
# 7c => 31b worth of data ... (similar density than hex)
sub word5 { # 20^4 * 26^3 words (4.5bit per letters)
 use integer;
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $a = ord($vo->[0]);
 my $odd = 0;
 my $str = '';
 while ($n > 0) {
   if ($odd) {
   my $c = $n % 20;
   #print "c: $c, n: $n\n";
      $n /= 20;
      $str .= $cs->[$c];
      $odd=0;
   } elsif(1) {
   my $c = $n % 26;
      $n /= 26;
      $str .= chr($a+$c);
      $odd=1;
   } else {
   #my $c = $n % 6;
   #   $n /= 6;
   #   $str .= $vo->[$c];
   #   odd=undef;
   }
 }
 return $str;
}
# -----------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 use integer;
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 if (1 && $n < 26) {
 $str = chr(ord('A') +$n%26);
 } else {
 $n -= 6;
 while ($n >= 20) {
   my $c = $n % 20;
      $n /= 20;
      $str .= $cs->[$c];
   #print "cs: $n -> $c -> $str\n";
      $c = $n % 6;
      $n /= 6;
      $str .= $vo->[$c];
   #print "vo: $n -> $c -> $str\n";
   
 }
 if ($n > 0) {
   $str .= $cs->[$n];
 }
 return $str;   
 }
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/DVS.pm,v $
