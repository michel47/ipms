#!/usr/bin/perl

package IPMS;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

# ---------------------------------------------------------------------
use if (exists $ENV{SITE}), lib => $ENV{SITE}.'/lib';
# ---------------------------------------------------------------------
use DVS qw(version hashr);

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');

our $PGW='https://gateway.ipfs.io';
    $PGW='https://cloudflare-ipfs.io';

#ipms add https://raw.githubusercontent.com/gradual-quanta/minichain/master/docs/keywords.txt --hash sha3-224 --cid-base base58btc
our $qmstatic='z6CfPtbmWhQCyNxEMAMFoHRJcRJyyi9KxVFdTaE46P3C'; # Alvaro F. Mangubat
# -----------------------------------------------------
sub encode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  my $h58 = Encode::Base58::BigInt::encode_base58($bint);
  $h58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  return $h58;
}
sub decode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $s = $_[0];
  # $e58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  $s =~ tr/A-HJ-NP-Za-km-z/a-km-zA-HJ-NP-Z/;
  my $bint = Encode::Base58::BigInt::decode_base58($s);
  my $bin = Math::BigInt->new($bint)->as_bytes();
  return $bin;
}
sub encode_base32 {
  use MIME::Base32 qw();
  my $mh32 = uc MIME::Base32::encode($_[0]);
  return $mh32;
}
sub decode_base32 {
  use MIME::Base32 qw();
  my $bin = MIME::Base32::decode($_[0]);
  return $bin;
}
# -----------------------------------------------------
sub encode_base32z {
  use MIME::Base32 qw();
  my $mh32 = uc MIME::Base32::encode($_[0]);
  $mh32 =~ y/A-Z2-7/ybndrfg8ejkmcpqxotluwisza345h769/;
  return $mh32;

}

# -----------------------------------------------------
sub resolve {
  my $iaddr = shift;
  my $mh = &ipmsrun('resolve '.$iaddr);
  printf "mh:%s.\n",YAML::Syck::Dump($mh) if $::dbug;
  return $mh->{ipath};
}
# -----------------------------------------------------
sub get_auth {
  my $auth = '*';
  my $ASKPASS;
  if (exists $ENV{IPMS_ASKPASS}) {
    $ASKPASS=$ENV{IPMS_ASKPASS}
  } elsif (exists $ENV{SSH_ASKPASS}) {
    $ASKPASS=$ENV{SSH_ASKPASS}
  } elsif (exists $ENV{GIT_ASKPASS}) {
    $ASKPASS=$ENV{GIT_ASKPASS}
  }
  if ($ASKPASS) { 
     use MIME::Base64 qw(encode_base64);
     local *X; open X, sprintf"%s %s %s|",${ASKPASS},'blockRing™';
     local $/ = undef; my $pass = <X>; close X;
     $auth = encode_base64(sprintf('michelc:%s',$pass),'');
     return $auth;
  } elsif (exists $ENV{AUTH}) {
     return $ENV{AUTH};
  } else {
    return 'YW5vbnltb3VzOnBhc3N3b3JkCg==';
  }
}
# -----------------------------------------------------
sub get_key {
  my $symb = shift;
  my $keys = &ipmsrun('key list -l');
  printf qq'%s.\n',Dump($keys) if $dbug == 1;
  return $keys->{$symb};
}
# -----------------------------------------------------
sub get_addr {
  my $mfspath = shift;
  my $mh = &ipms_get_api('files/stat',$mfspath,'&hash=1');
  printf "[get_addr] stat: %s.\n",YAML::Syck::Dump($mh) if $dbug;
  return $mh->{Hash};
}
# -----------------------------------------------------
sub get_hash_content {
  my $hash = shift;
  return undef unless defined $hash;
  my $buf = &ipms_get_api('cat',$hash);
  #printf "%s.\n",Dump($buf) if $dbug;
  return $buf;
}
# -----------------------------------------------------
sub get_repo_content {
  my $key = shift;
     $key = substr($key,1) if ($key =~ /^z/);
  my $keybin = &decode_base58($key);
  my $key32 = &encode_base32($keybin);
  my $split = substr($key32,-3,2);
  my $blockf = sprintf '%s/blocks/%s/%s.data', $ENV{IPFS_PATH},$split,$key32;
  my $buf;
  if (-e $blockf) {
    local *F; open F,'<',$blockf; local $/ = undef;
    $buf = <F>; close F;
  } else {
    $buf = "Status: 404 blockRing™ Content not Found\r\n";
    my $body = sprintf "404 : %s not found !\n",$blockf;
    $buf .= sprintf "Content-Length: %u\r\n",length($body);
    $buf .= "Content-Type: text/plain\r\n\r\n";
    $buf .= $body;
  }
  return $buf;
}
# -----------------------------------------------------
sub mfs_append {
  my ($text,$mpath) = @_;
  my $buf = &ipms_get_api('files/read',$mpath);
  $buf .= "$text";
  $buf .= "\n" if ($text !~ m/\n$/);
  # http://localhost:5001/api/v0/files/write?arg=<path>&offset=<value>&create=<value>
  #  &parents=<value>&truncate=<value>&count=<value>&raw-leaves=<value>&cid-version=<value>&hash=<value>
  my $mh = &ipms_post_api('files/write',$mpath,$buf,'&create=true&truncate=true');
  my $mh = &ipms_get_api('files/stat',$mpath,'&hash=true');
  return $mh;
}
sub mfs_copy {
   my $src = shift;
   my $dst = shift;
   my $parent = $dst; $parent =~ s,[^/]*$,,;
   my $mh = &ipms_get_api('files/stat',"$dst",'&hash=1');
   # printf "stat: %s.\n",YAML::Syck::Dump($mh);
   if (exists $mh->{Hash}) { # mfs:$dst exists !
      my $mh = &ipms_get_api('files/rm',"$dst");
      # printf "rm: %s.\n",YAML::Syck::Dump($mh);
   } else { # create the folder
      my $mh = &ipms_get_api('files/mkdir',"$parent",'&parents=true');
      # printf "mkdir: %s.\n",YAML::Syck::Dump($mh);
   }
   if (-f $src) { # src = files://*
     my $data = &file_read($src);
     my $mh = &ipms_post_api('files/write',$dst,"$data",'&create=1');
   } else { # src = /ipfs/*
     my $mh = &ipms_get_api('files/cp',"$src","&arg=$dst");
     # printf "cp: %s.\n",YAML::Syck::Dump($mh);
     return $?;
   }
}
# --------------------------------------------
sub mfs_write {
   my $data = shift;
   my $dst = shift;
   my $mh = &ipms_post_api('files/write',$dst,$data,'&create=true&truncate=true');
   my $mh = &ipms_get_api('files/stat',$dst,'&hash=true');
   return $mh;
}
sub mfs_read {
   my $mpath = shift;
   my $data = &ipms_get_api('files/read',$mpath);
   return $data;
}
# -----------------------------------------------------
sub ipfs_post_api {
  my $cmd = shift;
  my $data = shift;
  my $filename = 'blob.data';
  my $filepath = '/tmp/blob.data';
  if ($cmd eq 'add') {
     my $api_url;
     if ($ENV{HTTP_HOST} =~ m/heliohost/) {
        $api_url = sprintf'https://%s/api/v0/%%s?arg=%%s%%s','ipfs.blockringtm.ml';
     } else {
        my ($apihost,$apiport) = &get_apihostport();
        $api_url = sprintf'http://%s:%s/api/v0/%%s?arg=%%s%%s',$apihost,$apiport;
     }
     my $url = sprintf $api_url,$cmd,$filename,@_; # name of type="file"
     printf "url: %s\n",$url;
     use LWP::UserAgent qw();
     use HTTP::Request 6.07;
     use MIME::Base64 qw(encode_base64 decode_base64);
     my $ua = LWP::UserAgent->new();
     if ($ENV{HTTP_HOST} =~ m/heliohost/) {
        my $realm='Restricted Content';
        my $auth64 = &get_auth();
        my ($user,$pass) = split':',&decode_base64($auth64);
        $ua->credentials('ipfs.blockringtm.ml:443', $realm, $user, $pass);
#       printf "X-Creds: %s:%s\n",$ua->credentials('ipfs.blockringtm.ml:443', $realm);
     }
#    $ua->content($data);
     my $form = [
#       You are allowed to use a CODE reference as content in the request object passed in.
#       The content function should return the content when called. The content can be returned
#       Content => [$filepath, $filename, Content => $data ]
        'file-to-upload' => ["$filepath" => "$filename", Content => "$data" ]
     ];
     my $content = '5xx';
     my $resp = $ua->post($url,$form, 'Content-Type' => "multipart/form-data;boundary=immutable-file-boundary-$$");
     if ($resp->is_success) {
#       printf "X-Status: %s\n",$resp->status_line;
        $content = $resp->decoded_content;
#       printf qq'content: "%s"\n',$content;
     } else { # error ... 
        print "[33m";
        printf "X-api-url: %s\n",$url;
        print "[31m";
        printf "Status: %s\n",$resp->status_line;
        $content = $resp->decoded_content;
        local $/ = "\n";
        print "[32m";
        chomp($content);
        printf "Content: %s\n",$content;
        print "[0m";
     }
     use JSON qw(decode_json);
     my $json = &decode_json($content);
     return $json;


  } else {
     my $sha2 = &hashr('SHA256',1,$data);
     return 'z'.encode_base58(pack('H8','01551220').$sha2);
  }
}
# -----------------------------------------------------
sub ipms_get_api {
# ipms config Addresses.API
#  (assumed gateway at /ip4/127.0.0.1/tcp/5001/...)
   my $api_url;
   if ($ENV{HTTP_HOST} =~ m/heliohost/) {
      $api_url = sprintf'https://%s/api/v0/%%s?arg=%%s%%s','ipfs.blockringtm.ml';
   } else {
     my ($apihost,$apiport) = &get_apihostport();
      $api_url = sprintf'http://%s:%s/api/v0/%%s?arg=%%s%%s',$apihost,$apiport;
   }
   my $url = sprintf $api_url,@_; # failed -w flag !
#  printf "X-api-url: %s\n",$url;
   my $content = '';
   use LWP::UserAgent qw();
   use MIME::Base64 qw(decode_base64);
   my $ua = LWP::UserAgent->new();
   my $realm='Restricted Content';
   if ($ENV{HTTP_HOST} =~ m/heliohost/) {
      my $auth64 = &get_auth();
      my ($user,$pass) = split':',&decode_base64($auth64);
      $ua->credentials('ipfs.blockringtm.ml:443', $realm, $user, $pass);

#     printf "X-Creds: %s:%s\n",$ua->credentials('ipfs.blockringtm.ml:443', $realm);
   }
   my $resp = $ua->get($url);
   if ($resp->is_success) {
#     printf "X-Status: %s\n",$resp->status_line;
      $content = $resp->decoded_content;
   } else { # error ... 
      print "[33m";
      printf "X-api-url: %s\n",$url;
      print "[31m";
      printf "Status: %s\n",$resp->status_line;
      $content = $resp->decoded_content;
      local $/ = "\n";
      chomp($content);
      print "[32m";
      printf "Content: %s\n",$content;
      print "[0m";
   }
   if ($_[0] =~ m{^(?:cat|files/read)}) {
     return $content;
     if (0) {
	$content =~ s/"/\\"/g;
	$content =~ s/\x0a/\\n/g;
	$content = sprintf'{"content":"%s"}',$content;
	printf "Content: %s\n",$content;
     }
   }
   use JSON qw(decode_json);
   my $json = &decode_json($content);
   return $json;
}
# -----------------------------------------------------
sub ipms_post_api {
   use JSON qw(decode_json);
   use LWP::UserAgent qw();
   use HTTP::Request 6.07;
   my $cmd = shift;
   my $filename = shift;
   my $data = shift;
   my $opt = join'',@_;
   my $filepath = '/tmp/blob.data';
   my $api_url;
   # --------------------------------
   # selecting alternative endpoint :
   if ($ENV{HTTP_HOST} =~ m/heliohost/) {
      $api_url = sprintf'https://%s/api/v0/%%s?arg=%%s%%s','ipfs.blockringtm.ml';
   } else {
      my ($apihost,$apiport) = &get_apihostport();
      $api_url = sprintf'http://%s:%s/api/v0/%%s?arg=%%s%%s',$apihost,$apiport;
   }
   # --------------------------------
   if ($cmd =~ m/(?:add|write)$/) {
      my $url = sprintf $api_url,$cmd,$filename,$opt; # name of type="file"
      printf "url: %s\n",$url if $dbug;
      my $ua = LWP::UserAgent->new();
      if ($api_url =~ m/blockringtm\.ml/) {
         my $realm='Restricted Content';
         my $auth64 = &get_auth();
         my ($user,$pass) = split':',&decode_base64($auth64);
         $ua->credentials('ipfs.blockringtm.ml:443', $realm, $user, $pass);
#       printf "X-Creds: %s:%s\n",$ua->credentials('ipfs.blockringtm.ml:443', $realm);
      }
      my $form = [
#       You are allowed to use a CODE reference as content in the request object passed in.
#       The content function should return the content when called. The content can be returned
#       Content => [$filepath, $filename, Content => $data ]
#        'file-to-upload' => ["$filepath" => "$filename", Content => "$data" ]
         'file' => "$data"
      ];
      my $content = '5xx';
      my $resp = $ua->post($url,$form, 'Content-Type' => "multipart/form-data;boundary=immutable-file-boundary-$$");
      if ($resp->is_success) {
#       printf "X-Status: %s\n",$resp->status_line;
         $content = $resp->decoded_content;
#       printf qq'content: "%s"\n',$content;
      } else { # error ... 
         printf "X-api-url: %s\n",$url;
         printf "Status: %s\n",$resp->status_line;
         $content = $resp->decoded_content;
         local $/ = "\n";
         chomp($content);
         printf "Content: %s\n",$content;
      }
      if ($content =~ m/^{/) { # }
         my $json = &decode_json($content);
         return $json;
      } else {
         return $content;
      }


   } else {
      my $sha2 = &hashr('SHA256',1,$data);
      return 'z'.encode_base58(pack('H8','01551220').$sha2);
   }
}
# -----------------------------------------------------
sub get_gwhostport {
  my $IPFS_PATH = $ENV{IPFS_PATH} || $ENV{HOME}.'/.ipfs';
  my $conff = $IPFS_PATH . '/config';
  local *CFG; open CFG,'<',$conff or warn $!;
  local $/ = undef; my $buf = <CFG>; close CFG;
  use JSON qw(decode_json);
  my $json = decode_json($buf);
  my $gwaddr = $json->{Addresses}{Gateway};
  my (undef,undef,$gwhost,undef,$gwport) = split'/',$gwaddr,5;
      $gwhost = '127.0.0.1' if ($gwhost eq '0.0.0.0');
  my $url = sprintf'http://%s:%s/ipfs/zz38RTafUtxY',$gwhost,$gwport;
  my $ua = LWP::UserAgent->new();
  my $resp = $ua->get($url);
  if ($resp->is_success) {
    return ($gwhost,$gwport);
  } else {
    return ('ipfs.blockringtm.ml',443);
  }
}
# -----------------------------------------------------
sub get_apihostport {
  my $IPFS_PATH = $ENV{IPFS_PATH} || $ENV{HOME}.'/.ipfs';
  my $conff = $IPFS_PATH . '/config';
  local *CFG; open CFG,'<',$conff or warn $!;
  local $/ = undef; my $buf = <CFG>; close CFG;
  use JSON qw(decode_json);
  my $json = decode_json($buf);
  my $apiaddr = $json->{Addresses}{API};
  my (undef,undef,$apihost,undef,$apiport) = split'/',$apiaddr,5;
      $apihost = '127.0.0.1' if ($apihost eq '0.0.0.0');
  return ($apihost,$apiport);
}
# -----------------------------------------------------
# add,list,key,name,object,dag,block
sub ipmsrun ($) { 
  my $cmd = shift;
  print "// $cmd:\n" if $::dbug;
  local *EXEC; open EXEC, 'ipms '.$cmd.'|'; local $/ = "\n";
  my $mh = {};
  # -------------------------------------
  if ( $cmd =~ m/^(add|list|key|name|\w+store|\w+solve)/) {
     my $op = $1;
     while (<EXEC>) {
        print if ($::dbug || $dbug);
        $mh->{$2} = $1 if ($op eq 'ls' && m/(\w+)\s+\d+\s+(.*)\s*$/); # ls ...
        $mh->{$2} = $1 if ($op eq 'key' && m/^(Qm\S+)\s+(.*?)\s*$/); # key list -l

        $mh->{$2} = $1 if m/added\s+(\w+)\s+(.*)\s*$/; # add ...
        $mh->{'wrap'} = $1 if m/^(?:added\s+)?(\w+)\s*$/;

        $mh->{'hash'} = $1 if m/(Qm\S+|z[bd]\S+)/; # add -Q
        if (m,(/(ip[fn]s)/(Qm\S+|z[bd8]\S+)/?\S*),) {
            $mh->{'ipath'} = $1;
            $mh->{'hash'} = $3;
            $mh->{$2} = $3;
        } 
        if (m,ublished to (Qm\S+|z[bd8]\S+):,) {
            $mh->{'ipns'} = $1;
        }
        die $_ if m/Error/;
     }
     close EXEC;
     return $mh;
  # -------------------------------------
  } elsif ($cmd =~ m/^oneliner.../) {
     local $/ = "\n";
     my $buf = <EXEC>;
     chomp($buf);
     close EXEC;
     return $buf;
  # -------------------------------------
  } elsif ($cmd =~ m/^files/) {
     local $/ = undef;
     my $buf = <EXEC>;
     local $/ = "\n";
        chomp($buf);
     close EXEC;
     return $buf;

  # -------------------------------------
  } elsif ($cmd =~ m/^id/) {
     my $addrs = [];
     local $/ = "\n";
     while (<EXEC>) {
        chomp;
        push @$addrs, $_;
        die $_ if m/^Error/;
     }
     close EXEC;
     return $addrs;

  # -------------------------------------
  } elsif ($cmd =~ m/^cat/) {
     my $key = 'z83ajReAEg1SfNCAXGksPDMgNEW7YUN7J';
     if ($cmd =~ m/([\S]+)\s*$/) {
       my $arg = $1;
       if ($arg =~ m,/ipfs/([^/]+)$,) {
          $key = $1;
          $key = substr($key,1) if ($key =~ m/^z/);
       } else {
         #print "//info: resolve $arg\n";
         my $mh = &ipmsrun('resolve -r '.$arg);
         #printf "mh%s.\n",YAML::Syck::Dump($mh);
         $key = $mh->{hash};
       }
     }
     my $qm58 = ($key =~ m/^Qm/) ? $key : substr($key,1);
     my $id6 = substr($qm58,2,6);
     my $name5 = substr($qm58,4,5);
     my $cname = &cname($key);
     my $buf = '';
     while (<EXEC>) {
        $buf .= $_;
        die $_ if m/^Error/;
     }
     $mh->{key} = $key;
     $mh->{id6} = $id6;
     $mh->{name5} = $name5;
     $mh->{cname} = $cname;
     $mh->{content} = $buf;
# -------------------------------------
  } elsif ( $cmd =~ m/^dag\s+(\w+)/ ) {
        use JSON qw(decode_json);
        my $json = <EXEC>;
        $mh->{dag} = &decode_json($json);
     close EXEC;
     return $mh;
  # -------------------------------------
  } elsif ( $cmd =~ m/^block\s+(\w+)/ ) {
     my $op = $1;
     local $/ = undef;
     if ($op eq 'get') {
        $mh->{raw} = <EXEC>;
     } elsif ($op eq 'stat') {
        use YAML::Syck qw(Load);
        my $buf = <EXEC>;
        $mh = Load("--- \n".$buf);
     } else {
        local $/ = undef;
        $mh->{$op} = <EXEC>;
     }
     close EXEC;
     return $mh;

  } elsif ( $cmd =~ m/^object\s+(\w+)/ ) {
     my $op = $1;
     local $/ = undef;
     # ------------
     if ($cmd =~ /-encoding\s+protobuf/) {
        $mh->{proto} = <EXEC>;
     # ------------
     } elsif ($op eq 'get') {
        use JSON qw(decode_json);
        my $json = <EXEC>;
        $mh->{obj} = &decode_json($json);
     # ------------
     } elsif ($op eq 'links') {
        local $/ = "\n";
        while (<EXEC>) {
           if (m/^(\S+)\s+(\d+)(?:\s+(.*)\s*)?$/) { # links
             my ($key,$size,$name) = ($1,$2,$3);
             my $cname = &cname($key);
             my $mhash = &decode_mhash($key);
             my $mh32 = &encode_base32($mhash);
             my $split = substr($mh32,-3,2);
             my $file = sprintf'%s/%s.data',$split,$mh32;
             my $type = substr($mh32,0,3);
             my $hashid = substr($mh32,3,3);
             my $url = sprintf "%s/ipfs/b%s",$PGW,lc$mh32;
             $mh->{$cname} = { size => $size, key => $key, name => $name,
                file => $file, hashid => $hashid, url => $url
             };
           }
        }
     # ------------
     } elsif ($op eq 'stat') {
        use YAML::Syck qw(Load);
        my $buf = <EXEC>;
        $mh = Load("--- \n".$buf);
     } else {
        $mh->{$op} = <EXEC>;
     }
     close EXEC;
     return $mh;
  }
  # -------------------------------------
}
# -----------------------------------------------------------------------
sub decode_mhash {
  my $mh58 = shift;
  my $base = substr($mh58,0,1);
  my $mhxx = substr($mh58,1);
  my $addr;
  if ($base eq 'z') {
    $addr = &decode_base58($mhxx);
  } elsif ($base eq 'b') {
    $addr = &decode_base32($mhxx);
  } elsif ($base eq 'f') {
    $addr = pack'H*',$mhxx;
  } elsif ($base eq 'Q') {
    $addr = "\x01\x70".&decode_base58($mh58);
  } 

  my $maddr;
  my $cid = substr($addr,0,2);
  if ($cid eq "\x12\x20") { # ^Qm's case !
     $cid = "\x01\x70";
     $maddr = $cid.$addr;
  } else {
     $maddr = $addr;
  }
  my $hfunc = substr($maddr,2,2);
  my $mhash = substr($maddr,2);
  my $hash = substr($mhash,2);
  if (wantarray) {
    return ($addr,$maddr,$cid,$mhash, $hfunc,$hash);
  } else {
    return $addr;
  }
}


sub blockf {
  my $mh58 = shift;
  my $mhash = &decode_mhash($mh58);
  my $mh32 = &encode_base32($mhash);
  my $split = substr($mh32,-3,2);
  my $blockf = sprintf'blocks/%s/%s.data',$split,$mh32;
  return $blockf;
}
sub cname {
  my $mh58 = shift;
  my $mhash = &decode_mhash($mh58);
  my $mh32 = &encode_base32($mhash);
  my $qm58 = &encode_base58($mhash);
  my $type = substr($mhash,0,2);
  my $cname = '';
  if ($type eq "\x01\x55") {
    my $split = substr($mh32,-3,2);
    my $type = substr($mh32,0,3);
    my $name9 = substr($mh32,6,9);

    $cname=sprintf"%s/%s*%s",$split,$type,$name9;
  } elsif ($type eq "\x12\x20") {
    my $split = substr($mh32,-3,2);
    my $name4 = substr($mh32,3,4);
    $cname=sprintf"%s/CIQ%s",$split,$name4;
  } else {
    $cname = substr($mh32,0,9);
  }
  return $cname;
}

# CxRDT Merge :
sub merge_n {
 my ($myfile_h,@otherhashes) = @_;
 my $merged = $myfile_h; # 'z6CfPsNrajGLLoNHWshz5fm6JwY2HBYLAyTARUUwwhWe'; 
 foreach my $yourhash (@otherhashes) {
   $merged = &merge2($merged,$yourhash); 
 }
 return $merged;
}
sub merge2 {
  my ($a,$b) = @_;
  my $x = &common_ancestor($a,$b);
  my $hash = &merge3($a,$b,$x);
  return $hash;
}

sub merge3 {
 my ($ca,$cb,$cx) = map { &get_hash_content($_) } @_; # contents
 my ($pa,$pb,$px) = map { &remove_keywords($_) } ($ca,$cb,$cx); # payloads
 my ($a,$b,$x) = map { [ split(/\n/,$_) ] } ($pa,$pb,$px);
 if ($::dbug) {
    &write_file('a.txt',join"\n",@{$a});
    &write_file('b.txt',join"\n",@{$b});
    &write_file('x.txt',join"\n",@{$x});
 }
 my $mergexa = Text::Diff3::merge($a,$x,$b);
 my $mergexb = Text::Diff3::merge($b,$x,$a);
 if ($::dbug) {
  &write_file('mergexa.txt',join"\n",@{$mergexa->{body}});
  &write_file('mergexb.txt',join"\n",@{$mergexb->{body}});
 }
 my $body = '';
 my $meta = '';
 my (@n,@h);
 if ($mergexa->{conflict} == 0) {
   $body = join"\n",@{$mergexa->{body}};
   $meta = &extract_keywords($ca);
   @n = qw(a x b); @h = ($_[0], $_[2], $_[1]);
 } elsif ($mergexb->{conflict} == 0) {
   $body = join"\n",@{$mergexb->{body}};
   $meta = &extract_keywords($cb);
   @n = qw(b x a); @h = ($_[1], $_[2], $_[0]);
 } else {
   my $vote = &vote3($mergexa,$mergexb,$x);
   my $mergeab = ($vote) ? $mergexa : $mergexb;
   @n = ($vote) ? qw(a x b) : qw(b x a);
   @h = ($vote) ? ($_[0], $_[2], $_[1]) : ($_[1],$_[2],$_[0]);
   $body = join"\n",@{$mergeab->{body}};
   if ($::dbug) {
     unlink 'mergeab.txt';
     &write_file('mergeab.txt',$body);
   }
   $meta = ($vote) ? &extract_keywords($ca) : &extract_keywords($cb); 
 }
 #printf "body: %s.\n",$body;
 #printf "meta: %s.\n",Dump($meta);
 my $block = &set_keywords($body,$meta);
 $block =~ s/^<<<<<<<$/<<<<<<< $n[0]: $h[0]/m;
 $block =~ s/^\|\|\|\|\|\|\|$/||||||| $n[1]: $h[1]/m;
 $block =~ s/^=======$/======= $n[2]: $h[2]/m;
 printf "block: %s.\n",$block if $dbug;
 if ($::dbug) {
  &write_file('merged.txt',$block);
 }
 my $mh = &ipms_post_api('add',$block);

 return $mh->{Hash};
}

sub vote3 {
 print STDERR "error: conflict !\n";
 return (rand() < 0.5) ? 0 : 1;
}

sub common_ancestor {
   my $attr = {};
   my ($a,$b) = @_;
   #list ancestor of head node graph a
   my $aa = [ &get_ancestors($a) ];
   printf "aa: [%s]\n",join', ',map { shorthash($_); } @{$aa} if $dbug;
   &mark($attr,$aa,{color => 1}); # red nodes
   my $ab = [ &get_ancestors($b) ];
   printf "ab: [%s]\n",join', ',map { shorthash($_); } @{$ab} if $dbug;
   &mark($attr,$ab,{color => 2}); # blue nodes
   printf "attr: %s.\n",Dump($attr) if $dbug;
   # commons ancestors (vertices)
   my $ca_v = &filter($attr,[keys(%$attr)],{color => 3}); # purple nodes
   printf "ca(purple): [%s]\n",join',',map { &shorthash($attr->{$_}{node}[0]); } @{$ca_v} if $dbug;
   for my $vertex (@{$ca_v}) {
      #y $vertex = &get_vertex($block);
      printf "vertex: %s : node: %s\n", map { &shorthash($_); } ($vertex,$attr->{$vertex}{node}[0]) if $dbug;
      $attr->{$vertex}{cnt} = 0 if (! defined $attr->{$vertex}{cnt});
      foreach my $n (@{$attr->{$vertex}{node}}) {
         my $parents = &get_parents($n); next unless $parents;
         for my $p (@{$parents}) {
            my $v = &get_vertex($p);
            $attr->{$v}{cnt} += 1;
         }
      }
   }
   # closest ancestors are the ones w/ cnt == 0;
   my $cca = &filter($attr,$ca_v,{cnt => 0});
   printf "cca: [%s]\n",join', ',@{$cca} if $dbug;
   return $attr->{$cca->[0]}{node}[0]; # return the first node corresponding to vertex !
}
sub get_ancestors {
  my $block = shift;
 return undef unless defined $block;
 my @ancestors = ();
 my @parents = @{ &get_parents($block) }; # parent are block's hash too (nodes, eventhough we interrested in they payload only)
 if (scalar(@parents) == 0) {
     #@parents = map { &get_payload_hash($_); } @previous 
     @parents = @{ &get_previous($block) };  # addresses (block's hash) (nodes)
 }
 printf "parents(%s): [%s]\n",$block,join',',map { &shorthash($_); } @parents if $dbug;
 push @ancestors, @parents;
 foreach my $p (@parents) {
   my @grandpa = &get_ancestors($p); # recursion
   printf " grandpa=a(%s): [%s]\n",$p,join',', map { &shorthash($_); } @grandpa if $dbug;
   push @ancestors, @grandpa if @grandpa;
 }
 printf "ancestors(%s): [%s]\n",$block,join',', map { &shorthash($_); } @ancestors if $dbug;
 return @ancestors;
}

sub mark {
  my ($attr,$list,$kv) = @_;
  foreach my $n (@{$list}) {
    printf "[mark]: n=%s ",$n if $dbug;
    my $v = &get_vertex($n);
    push @{$attr->{$v}{node}}, $n;
    foreach my $k (keys %{$kv}) {
      printf "%s:%s\n",$k,$kv->{$k} if $dbug;
      $attr->{$v}{$k} |= $kv->{$k}; # bitwise or for "additive" colors
    }
  }
  return $?;
}
sub filter {
  my $attr = shift; # hash of vertices attributes
  my $list = shift; # list of nodes
  my $req = shift;
  my @results = ();
  foreach my $k (keys %{$req}) {
  foreach my $v (@{$list}) {
    #printf "a{%s}{%s} = %s =? %s\n",$n,$k,$attr->{$n}{$k},$req->{$k};
    if ($attr->{$v}{$k} == $req->{$k}) {
      push @results, $v;
      #printf "results: %s\n",join', ',@{$results};
    }
   }
 }
 return [ @results ];
}

sub get_parents { # all parents are nodes
  my $n = shift;
  my $buf = &get_hash_content($n);
  #printf "content(%s): %s.\n",$n,nonl($buf,0,76);
  if ($buf eq '') {
    return [];
  } else {
    my $prev = &extract_keywords($buf,'parents');
    return ($prev) ? $prev : [];
  }
}
sub get_previous {
  my $n = shift;
  my $buf = &get_hash_content($n);
  if ($buf eq '') {
    return [];
  } else {
     my $prev = &extract_keywords($buf,'previous');
#    printf "prev(%s): %s\n",$n,$prev;
     return ($prev) ? $prev : [];
  }
}
sub get_vertex {
  my $n = shift;
  my $buf = &get_hash_content($n);
  #printf"[vtx]: %s=%s\n",$n,&nonl($buf,0,36);
  my $payload = &remove_keywords($buf);
  #printf qq'payload: "%s"\n',&nonl($payload);
  my $sha2 = &hashr('SHA256',1,$payload);
  return 'z'.encode_base58(pack('H8','01551220').$sha2);
}

sub extract_keywords {
   my $keywords = {};
   my $buf = shift;
   my $kw = shift;
   #printf "kw: %s\n",$kw;
   #printf "[xkw]: kw=%s; content=%s.\n",$kw,&nonl($buf,0,36);
   $buf =~ s/\$qm: .*\s*\$/\$qm: $qmstatic\$/;
   my $qm = 'z'.&encode_base58(pack('H8','01551220').&hashr('SHA256',1,$buf));
   $keywords->{qm} = $qm;
   # /!\ keywords regexp loop ... w/ lookbehind " or \n and lookahead \\
   while ($buf =~ m/(?<![\\\$])\$([A-Z]\w+|qm|source|parents|mutable|previous|next|tic|spot):\s*([^\\\$]*?)\s*(?>!\\)?\$(?=['"\s])/g) {
      printf "debug: %s %s (pos: %d)\n",$1,$2, pos $buf if $dbug;
      my $keyw=$1;
      my $value = ($2 eq '~') ? undef : $2;
      if ($value =~ m/,/) {
        $keywords->{$keyw} = [ split(/,\s*/,$value) ];
      } elsif ($keyw =~ m/parents$/) {
        $keywords->{$keyw} = [ $value ];
      } else {
        $keywords->{$keyw} = $value;
      }
   }
   #printf "xkw(qm=%s): kw=%s keywords=%s.\n",substr($qm,0,7),$kw,&nonl(YAML::Syck::Dump($keywords));
   if (defined $kw) {
     return $keywords->{$kw};
   } else {
     return $keywords;
   }
}
sub set_keywords {
   my $buf = shift;
   my $dict = shift;
   my $spot = &get_spot($^T);
   use YAML::Syck qw(Dump);
   printf "dict: %s.\n",YAML::Syck::Dump($dict);
   foreach my $kw (reverse sort keys %{$dict}) {
      #printf "%s: %s\n",$kw,$dict->{$kw};
      if (ref($dict->{$kw}) eq 'ARRAY') {
        $dict->{$kw} = join', ',@{$dict->{$kw}};
      }
      $buf =~ s/(?<![\\\$])\$$kw: [^\$]*\s*(?<!\\)?\$(?=['"\s])?/\$$kw: $dict->{$kw}\$/gm;
      #my $KW = $kw; $KW =~ s/.*/\u$&/;
      #$buf =~ s/(?!\\)\$$KW: [^\$]*\s*\$$/\$$KW: $dict->{$kw}\$/gm;
   }
   # compute payload (w/ original file i.e. before substitution)
   $buf =~ s/\$qm: [^\$]*\s*\$$/\$qm: $qmstatic\$/m;
   my $qm = 'z'.&encode_base58(pack('H8','01551220').&hashr('SHA256',1,$buf));
   $buf =~ s/\$qm: [^\$]*\s*\$$/\$qm: $qm\$/m; # replace w/ current qm
   $buf =~ s/\$tic: [^\$]*\s*\$$/\$tic: $^T\$/m; # update timestamp
   $buf =~ s/\$spot: [^\$]*\s*\$$/\$spot: $spot\$/m; # update space-time spot!

   return $buf;

}
sub remove_keywords {
   my $buf = shift;
   $buf =~ s/(?<![\\\$])\$([A-Z]\w+):\s*([^\\\$]*?)\s*\$(?=['"\s])/\$$1: \$/g;
   $buf =~ s/(?<![\\\$])\$(qm|parents|previous|next|tics?|spot):\s*([^\\\$]*?)\s*\$(?=['"\s])/\$$1: $qmstatic\$/g;
   return $buf;
}

sub shorthash {
  my $hash = shift;
  my $s1 = ($hash =~ m/^zb2/) ? substr($hash,3,5) : substr($hash,0,5);
  my $s2 = substr($hash,-4);
  return $s1.'...'.$s2;
}

# -----------------------------------------------------------------------
sub get_spot {
   my $tic = shift || $^T;
   my $nonce;
   if (@_) {
     use Digest::MurmurHash qw();
     $nonce = Digest::MurmurHash::murmur_hash(join'',@_);
   } else {
     $nonce = 0xA5A5_5A5A;
   }
   printf "nonce f%08x\n",$nonce;
   my $dotip = &get_localip;
   printf "dotip: %s\n",$dotip;
   my $pubip = &get_publicip;
   printf "pubip: %s\n",$pubip;
   my $lip = unpack'N',pack'C4',split('\.',$dotip);
   my $nip = unpack'N',pack'C4',split('\.',$pubip);
   my $seed = srand($nip);
   printf "seed: f%08x\n",$seed;
   my $salt = int rand(59);
   printf "salt: %s\n",$salt;
   my $time = 59 * int (($tic - 58) / 59) + $salt;
   my $spot = $time ^ $nip ^ $lip ^ $nonce;
   return $spot;
}
# -----------------------------------------------------------------------
sub get_localip {
    use IO::Socket::INET qw();
    # making a connectionto a.root-servers.net

    # A side-effect of making a socket connection is that our IP address
    # is available from the 'sockhost' method
    my $socket = IO::Socket::INET->new(
        Proto       => 'udp',
        PeerAddr    => '198.41.0.4', # a.root-servers.net
        PeerPort    => '53', # DNS
    );
    return '0.0.0.0' unless $socket;
    my $local_ip = $socket->sockhost;

    return $local_ip;
}
# -----------------------------------------------------------------------
sub get_publicip {
 use LWP::UserAgent qw();
  my $ua = LWP::UserAgent->new();
  my $url = 'http://iph.heliohost.org/cgi-bin/remote_addr.pl';
     $ua->timeout(7);
  my $resp = $ua->get($url);
  my $ip;
  if ($resp->is_success) {
    my $content = $resp->decoded_content;
    chomp($content);
    $ip = $content;
  } else {
    print "X-Error: ",$resp->status_line;
    my $content = $resp->decoded_content;
    $ip = '127.0.0.1';
  }
  return $ip;
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/IPMS.pm,v $
