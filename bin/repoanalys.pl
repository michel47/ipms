#!/usr/bin/perl

# Infinite Repos:
#  cold : 1st created
#  hot : last created
#  random 
#  pinned : cluster matching peerid
my $maxsize = 50; # in GB
my $maxnbf = $maxsize*1024*1048576 / 256 / 1025;
my $repodir;
if (exists $ENV{IPFS_PATH}) {
 $repodir = $ENV{IPFS_PATH} . '/blocks';
} else {
 $repodir = $ENV{HOME} . '/.ipfs/blocks';
}
printf "repos: %s\n",$repodir;
my $en=log($maxnbf)/log(32);
printf "entropy: %fc\n",$en;
$l = int( $en - 0.4999 );
printf "len: %d\n",$l;
printf "max: %.1fG estim\n",(32**($l)) * 256 / 1024 / 1024;

local *D; opendir D,$repodir;
my @content = grep /^\w{2}$/, readdir(D); closedir D;
printf "nshards: %d\n",scalar(@content);

my %clusters = ();
foreach my $shard (@content) {
   my $subdir = $repodir.'/'.$shard;
   local *D; opendir D,$subdir; my @list = grep /.*\.data/, readdir(D); closedir D;
   my $nb = scalar(@list);
   foreach my $blob (@list) {
     my $short;
     if ($blob =~ /^CIQ/) {
       my $shard0 = ($nb > 36) ? substr($shard,-1) : $shard; 
       $short = sprintf '%s%s*%s.',$&,substr($blob,3,$l),$shard0;
    } elsif ($blob =~ /^AFK.../) {
       #printf "blob: %s\n",$blob;
       $short = sprintf 'b%s%s*%s.',$&,substr($blob,6,$l),$shard;
    } elsif ($blob =~ /^AFY/) { # bafy files ...
       #printf "blob: %s\n",$blob;
       $short = sprintf 'bAFY..%s*%s.',substr($blob,5,$l),'..';
    } elsif ($blob =~ /^AF4.../) { # GIT blobs ... 
       #printf "blob: %s\n",$blob;
       $short = sprintf 'bAF4..%s*%s.',substr($blob,5,$l),$shard;
    } else {
       printf "blob: blocks/%s/%s\n",$shard,$blob;
       $short = substr($blob,0,$l+3).'*'.$shard;
    }
     push @{$clusters{$short}}, $blob;
   }
   if ($nb > 36) {
     printf "shard: %s; %s files\n",$shard,$nb;
   }
   $tnf += $nb;
}
my $nc = scalar(keys %clusters);
printf "repo: %.3fK files (~%.1fG)\n",$tnf/1024,$tnf*256/1024/1024;
printf "nclus: %.3fK clusters\n",$nc / 1024;
printf "size: %.3fG estim\n",$nc * 256 / 1024 / 1024;
foreach my $clus (keys %clusters) {
   my $nf = scalar(@{$clusters{$clus}});
   if ($nf > 2) {
      printf "%s: %d blobs\n",$clus,$nf;
   } 
}
exit $?;
# vim: sw=3 et ai
1; # $Source: /my/perl/scripts/repoprune.pl $

