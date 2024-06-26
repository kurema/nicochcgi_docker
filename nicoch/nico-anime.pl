#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use File::Spec;
use LWP::UserAgent;
use URI;
use WWW::NicoVideo::Download;
use Web::Scraper;
use XML::Simple;
#use Net::Netrc;

use URI::Escape;
use JSON;

use File::Path;

require File::Spec->catfile(dirname(__FILE__),"common.pl");

binmode(STDOUT, ":utf8");

$| = 1;

print "Log\nTime: ".time."\n";

print "Locked...\n";
open(LOCK, File::Spec->catfile(dirname(__FILE__),"lock"));
flock(LOCK, 2);
print "Unlocked!\n";

#my $mach = Net::Netrc->lookup('nicovideo');
#my ($nicologin, $nicopassword, $nicoaccount) = $mach->lpa;

#my $client = WWW::NicoVideo::Download->new(
#    email => $nicologin,
#    password => $nicopassword,
#);

my %conf=GetConf("/etc/nicochcgi/nicoch.conf");
my @url = GetChannels();

my $client = WWW::NicoVideo::Download->new(
    email => $conf{"niconico_id"},
    password => $conf{"niconico_password"},
);

my $animedir=$conf{"dlhome"};
#my $animedir=dirname(__FILE__)

foreach my $url (@url) {
    my $video;
    my $video2;
    eval{
    $video = scraper {
        process '.g-video-title .g-video-link', 'title' => 'TEXT', 'url[]' => '@href';
    }->scrape(URI->new($url));
    $video2 = scraper {
        process '.thumb_video', 'title' => 'TEXT', 'url[]' => '@href';
    }->scrape(URI->new($url."/video"));
    };
    sleep(1);
    if($@){
        warn "ERROR: $@\n";
        next;
    }

    my ($chid) = $url =~ m!/([^/]+?)/?$!;
    my $chdir=File::Spec->catfile($animedir , $chid );
    if(! -d $chdir){
      mkdir $chdir;
      chmod 0777, $chdir;
    }

    foreach my $surl (@{$video->{url}},@{$video2->{url}}){
        my ($video_id) = $surl =~ m!/watch/(\w+)!;

        my $ext = "mp4";

        my @testfile=glob("\"".File::Spec->catfile($chdir , "$video_id.*.$ext")."\"" );
        next if @testfile+0 >0;
        
        #my $ext = $info->{video}->{movieType};
        my $info = GetInfo($client->user_agent,$video_id,$chid);
        sleep(1);

        my $title;
        my $getthumbinfo_res;
        if(defined($info)){
          $title = $info->{video}->{title};
        }else{
          $getthumbinfo_res = $client->user_agent->get("http://ext.nicovideo.jp/api/getthumbinfo/$video_id");
          $title = XMLin($getthumbinfo_res->content)->{thumb}{title};
          $ext = XMLin($getthumbinfo_res->content)->{thumb}{movie_type};
          
          my @testfile2=glob("\"".File::Spec->catfile($chdir , "$video_id.*.$ext")."\"" );
          next if @testfile2+0 >0;
        }

        $title=~ s/[\/\\\:\,\;\*\?\"\<\>\|]//g;

        my @testfile3=glob("\"".File::Spec->catfile($chdir , "*.$title.$ext")."\"" );
        next if @testfile3+0 >0;

        my $fileold = File::Spec->catfile($chdir , "$video_id.$ext");
        my $file = File::Spec->catfile($chdir , "$video_id.$title.$ext");
        my $filetmp = File::Spec->catfile($chdir , "tmp.$ext");
        unlink $filetmp if -e $filetmp;
        next if -e $file;

        if(-e $fileold ) {
            rename $fileold,$file;
            next;
        }

        print "Download $file\n";
        open my $fh, '>', $filetmp or die $!;
        binmode($fh);
        eval {
          my ($dl_size, $dl_downloaded, $is_hls) = DownloadVideo($info,$video_id,$chid,$client,0,$fh,$chdir,$conf{"support_hls_enc"});
          if($is_hls){
            if(-e $filetmp){
              chmod 0666,$filetmp;
              rename $filetmp,$file;
            }
            return;
          }
          
          if($dl_downloaded!=$dl_size && $dl_size != -1){
            my $dl_size_org=$dl_size;
            my $i=0;
            my $max_retry_count=5;
            while($i<$max_retry_count && $dl_downloaded!=$dl_size_org){
              $i++;
              print $dl_downloaded."B / ".$dl_size_org."B downloaded. Continue.\n";
              sleep 30;
              
              $info = GetInfo($client->user_agent,$video_id,$chid);
              sleep(1);
              
              my ($dl_size_left, $dl_downloaded_current) = DownloadVideo($info,$video_id,$chid,$client,$dl_downloaded,$fh);
              if ($dl_size_left+$dl_downloaded!=$dl_size){die "Content-Length missmatch: ".($dl_size_left+$dl_downloaded)." : ".($dl_size);}
              $dl_downloaded += $dl_downloaded_current;
            }
          
            if($dl_downloaded!=$dl_size_org){
              unlink $filetmp;
              die "Only ".$dl_downloaded."B / ".$dl_size_org."B downloaded.";
            }
          }
          if($dl_downloaded == 0){
            die "Downloaded file empty.";
          }
          else{
            chmod 0666,$filetmp;
            rename $filetmp,$file;
          }
        };
        sleep 10;
        if ($@) {
          warn "ERROR: $@\n";
          unlink $filetmp;
          next;
        }
    }
}

print "Time: ".time."\nDone\n";

sub DownloadVideo{
  my ($info,$video_id,$chid,$client,$range_from,$fh,$working_dir,$support_HLS_enc)=@_;
  
  if(! defined($info)){
    $info = GetInfo($client->user_agent,$video_id,$chid);
    sleep(1);
  }

  my $vurl="";
  my $session_uri;
  my $json_dsr;
  my $is_hls=0;
  if(defined($info) && defined($info->{media}->{delivery}->{movie}->{session}->{videos})){
    $vurl = $info->{video}->{smileInfo}->{url};
    if (defined($vurl) && $vurl=~ /low$/){die "low quality";}
    #if (@{$info->{video}->{dmcInfo}->{quality}->{videos}}+0 != @{$info->{media}->{delivery}->{movie}->{session}->{videos}}+0){die "low quality";}
    if($info->{media}->{delivery}->{movie}->{session}->{videos}[0] =~ /low$/){die "low quality";}
    ($json_dsr,$session_uri) = GetHtml5VideoJson($info, $client->user_agent);
    if(defined($json_dsr) && defined($json_dsr->{data}->{session}->{content_uri})){
      print "Access via api.dmc.nico\n";
      if(defined($info->{media}->{delivery}->{encryption})){
        $is_hls=1;
        print "Using HLS encrypted connection.\n";
      }
      $vurl = $json_dsr->{data}->{session}->{content_uri};
    }else{
      die "Failed: https://api.dmc.nico/api/sessions\n";
    }
  }elsif(defined($info) && defined($info->{media}->{domand})){
    $is_hls=2;
    print "Access via Dwango Media Service\n";
  }else{
    $vurl= $client->prepare_download($video_id);
  }
  if ($vurl=~ /low$/){die "low quality!\n";}

  my $ping_content;
  if(defined($json_dsr)){
    $ping_content=encode_json({session => $json_dsr->{data}->{session}});
  }
  if($is_hls==0){
    return DownloadFile($vurl,$client->user_agent,$fh,$range_from,$session_uri,$json_dsr->{data}->{session}->{id},$ping_content);
  }

  # Turn off/on next line to enable/disable HLS encryption.
  if(! defined($support_HLS_enc) || $support_HLS_enc eq "false"){die "HLS encryption not supported.";}
  
  my $dir_tmp = File::Spec->catfile($working_dir , $video_id.".hls/");
  my $ua=$client->user_agent;
    
  if(-e File::Spec->catfile($dir_tmp,"done")){
    print "Already downloaded (Not converted.)\n";
    return (0,0,1);
  }
  
  my $m3u8_uri = "";
  if($is_hls==2){
    # https://github.com/AlexAplin/nndownload/blob/master/nndownload/nndownload.py
    # Copyright (c) 2024 Alex Aplin
    # MIT License
    my $access_right_key = $info->{media}->{domand}->{accessRightKey};
    my $watch_track_id = $info->{client}->{watchTrackId};

    my @domand_videos = @{$info->{media}->{domand}->{videos}};
    my $best_video_id = "video-h264-720p";
    foreach my $domand_video (@domand_videos){
      if($domand_video->{isAvailable}){
        $best_video_id = $domand_video->{id};
        last;
      }
    }
    my @domand_audios = @{$info->{media}->{domand}->{audios}};
    my $best_audio_id = "audio-aac-192kbps";
    foreach my $domand_audio (@domand_audios){
      if($domand_audio->{isAvailable}){
        $best_audio_id = $domand_audio->{id};
        last;
      }
    }

    my $dms_watch_api = "https://nvapi.nicovideo.jp/v1/watch/".$video_id."/access-rights/hls?actionTrackId=".uri_escape($watch_track_id);
    my $request_option=HTTP::Request->new( "OPTIONS" , $dms_watch_api );
    $ua->request($request_option);
    
    my $request_post = HTTP::Request->new( "POST" , $dms_watch_api );
    $request_post->header( "X-Access-Right-Key" => $access_right_key );
    $request_post->header( "X-Request-With" => "https://www.nicovideo.jp" );
    $request_post->header( "X-Frontend-Id" => "6" );
    $request_post->header( "X-Frontend-Version" => "0" );
    $request_post->header( "X-Niconico-Language" => "ja-jp" );
    $request_post->content("{\"outputs\":[[\"".$best_video_id."\",\"".$best_audio_id."\"]]}"); #Predefined value is not very good.
    my $manifest_res = decode_json($ua->request($request_post)->content);

    $m3u8_uri = $manifest_res->{data}->{contentUrl}; # Url of m3u8
  }else{
    #$ua->default_header( "Origin" => "https://www.nicovideo.jp" );
    #$ua->default_header( "Referer" => "https://www.nicovideo.jp/watch/$video_id" );
    #$ua->agent('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36 Vivaldi/2.2.1388.37');
    
    {
      #以下を参考に。
      #https://github.com/tor4kichi/Hohoema/issues/778
      #これを正しくセットしないと動きません。
      my $ping_uri="https://nvapi.nicovideo.jp/v1/2ab0cbaa/watch?t=".uri_escape($info->{media}->{delivery}->{trackingId});

      my $request_option=HTTP::Request->new( "OPTIONS" , $ping_uri );
      $ua->request($request_option);

      my $request_get=HTTP::Request->new( GET => $ping_uri );
      $request_get->header( "X-Frontend-Id" => "6" );
      $request_get->header( "X-Frontend-Version" => "0" );
      $request_get->header( "X-Niconico-Language" => "ja-jp" );
      $request_get->header( "Origin" => "https://www.nicovideo.jp" );
      $request_get->header( "Referer" => "https://www.nicovideo.jp/watch/$video_id" );
      
      my $res=$ua->request( $request_get );
      if(decode_json($res->content)->{meta}->{status} ne "200"){
        print "Ping failed : $ping_uri\nContinue\n";
      }
      $m3u8_uri = $json_dsr->{data}->{session}->{content_uri}
    }
  }

  my $m3u8_playlist_local;

  {
    if(-d $dir_tmp){
      rmtree $dir_tmp;
    }
    mkdir $dir_tmp;
    chmod 0777, $dir_tmp;
  }   

  if($is_hls==2){
    my (undef,$m3u8_playlist_local_tmp)=GetM3u8Path($m3u8_uri,$dir_tmp);
    $m3u8_playlist_local=$m3u8_playlist_local_tmp;
    DownloadM3u8($m3u8_uri,$m3u8_playlist_local,$ua,$dir_tmp);
    #return (0,0,1);
  }else{
    
    my $m3u8_master_res = $ua->get($m3u8_uri);

    {
      open my $fh_m3u8, '>', File::Spec->catfile($dir_tmp,GetFileName($m3u8_uri)) or die $!;
      print {$fh_m3u8} $m3u8_master_res->content;
      close($fh_m3u8);
    }
    
    my $m3u8_playlist;

    {
      foreach my $line (split(/\n/,$m3u8_master_res->content)){
        if($line=~ /^\#/){next;}
        $m3u8_playlist = $line;
      }
      if(! defined($m3u8_playlist)){die "No playlist provided.";}
      my $m3u8_master_dir=$m3u8_uri;
      $m3u8_master_dir=~ s/\/[^\/]+?$/\//;
      $m3u8_playlist = $m3u8_master_dir.$m3u8_playlist;
      $m3u8_playlist_local=File::Spec->catfile($dir_tmp,GetFileName($m3u8_playlist));
    }
    
    my $m3u8_playlist_res = $ua->get($m3u8_playlist);

    {
      open my $fh_m3u8_org, '>', $m3u8_playlist_local.".org" or die $!;
      print {$fh_m3u8_org} $m3u8_playlist_res->content;
      close($fh_m3u8_org);
    }
    
    {
      open my $fh_m3u8, '>', $m3u8_playlist_local or die $!;
      my $content = $m3u8_playlist_res->content;
      $content=~ s/([\n\r][^\#\n\r][^\?\n\r]*)\?[^\?\n\r]+([\n\r])/$1$2/g;
      $content=~ s/([\n\r]\#EXT-X-KEY:.+URI=)"[^"]+"/$1"\.\/hls.key"/;
      print {$fh_m3u8} $content;
      close($fh_m3u8);
    }
    
    my $m3u8_playlist_dir = $m3u8_playlist;
    $m3u8_playlist_dir =~ s/\/[^\/]+?$/\//;
    
    if($is_hls==1)
    {
      open my $fh_hls_key_json, '>', File::Spec->catfile($dir_tmp,"hls_info.json") or die $!;
      print {$fh_hls_key_json} encode_json($info->{media}->{delivery}->{encryption});
      close($fh_hls_key_json);
    }

    my $last_ping = time;
    #my $hls_key_url = $info->{media}->{delivery}->{encryption}->{keyUri};
    my $hls_key_url = $info->{media}->{delivery}->{encryption}->{keyUri};

    foreach my $line (split(/\n/,$m3u8_playlist_res->content)){
      chomp($line);
      if($line=~ /^\#EXT-X-KEY:.+URI="([^"]+)"/){
        $hls_key_url = $1;
        
        {
          #my $hls_key_res = $ua->get($hls_key_url);
          my $request=HTTP::Request->new( GET => $hls_key_url );
          $request->header( "Cache-Control" => "no-cache" );
          $request->header( "Pragma" => "no-cache" );
          if($is_hls==2){
            $request->header( "Referer" => "https://www.nicovideo.jp/" );
          }else{
            $request->header( "Referer" => "https://www.nicovideo.jp/watch/$video_id" );
          }
          my $hls_key_res=$ua->request( $request );
          
          open my $fh_hls_key, '>', File::Spec->catfile($dir_tmp,"hls.key") or die $!;
          binmode($fh_hls_key);
          #DownloadFile($hls_key_url,$ua,$fh_hls_key);
          print {$fh_hls_key} $hls_key_res->content;
          close($fh_hls_key);
          
          sleep(1);
        }
        
        next;
      }
      if($line eq ""){
        next;
      }
      if($line=~ /^\#/){next;}
      {
        #my $ts_res = $ua->get($m3u8_playlist_dir.$line);
        my $request=HTTP::Request->new( GET => $m3u8_playlist_dir.$line );
        $request->header( "Origin" => "https://www.nicovideo.jp" );
        if($is_hls==2){
          $request->header( "Referer" => "https://www.nicovideo.jp/" );
        }else{
          $request->header( "Referer" => "https://www.nicovideo.jp/watch/$video_id" );
        }
        my $ts_res=$ua->request( $request );
        
        if (! $ts_res->is_success || $ts_res->header( "Content-Length" ) +0 != length($ts_res->content)) {
          die "Download failure: ".$m3u8_playlist_dir."\n".$line;
        }
        
        #鍵はアクセスごとに変わる。
        #tsファイルはセッションごとに変わる。
        
        open my $fh_ts, '>', File::Spec->catfile($dir_tmp,GetFileName($line)) or die $!;
        binmode($fh_ts);
        print {$fh_ts} $ts_res->content;
        close($fh_ts);
        
        $last_ping = PingSession($ua,$session_uri,$json_dsr->{data}->{session}->{id},$ping_content,$last_ping);

        next;
      }
    }
    }
    
    {
      open my $fh_done, '>', File::Spec->catfile($dir_tmp,"done") or die $!;
      close($fh_done);
    }
    
    {
      my $tmp_mp4=File::Spec->catfile($working_dir , "tmp.mp4" );
      unlink $tmp_mp4;
      open my $rs, "ffmpeg -allowed_extensions ALL -i \"$m3u8_playlist_local\" -c copy -bsf:a aac_adtstoasc -loglevel error \"$tmp_mp4\" 2>&1 |";
      my @result = <$rs>;
      if(@result + 0 != 0){
        my $results=join(';', @result);
        print "ffmpeg result : $results \n";
      }
      close($rs);
      #print "ffmpeg -allowed_extensions ALL -i \"$m3u8_playlist_local\" -c copy -bsf:a aac_adtstoasc \"$tmp_mp4\"\n";
      if(-e $tmp_mp4 && -d $dir_tmp){
        rmtree $dir_tmp;
      }
    }
    
    return (0,0,1);
  }

#https://github.com/kurema/nicochcgi_docker/blob/master/nicoch/nico-anime.pl
sub DownloadM3u8{
  my ($m3u8_uri,$m3u8_fn,$ua,$dir_tmp)=@_;
  my $m3u8_res = $ua->get($m3u8_uri);
#print "$m3u8_uri\n($m3u8_fn,$ua,$dir_tmp)\n";
  {
    open my $fh_m3u8_org, '>', $m3u8_fn.".org" or die $!;
    print {$fh_m3u8_org} $m3u8_res->content;
    close($fh_m3u8_org);
  }
  open my $fh_m3u8, '>', $m3u8_fn or die $!;
  foreach my $line (split(/\n/,$m3u8_res->content)){
    if($line=~ /^\s*$/){
      print {$fh_m3u8}  $line;
      next;
    }elsif($line=~ /^https?:\/\//i){
      my $line_uri_bn=GetFileName($line);
      chomp($line_uri_bn);
      
      if($line_uri_bn=~ /\.m3u8$/i){
        my ($m3u8_path_relative,$m3u8_path)=GetM3u8Path($line,$dir_tmp);
        DownloadM3u8($line,$m3u8_path,$ua,$dir_tmp);
        print {$fh_m3u8} $m3u8_path_relative."\n";
      }else{
        DownloadBinary($line,File::Spec->catfile($dir_tmp,$line_uri_bn),$ua);
        print {$fh_m3u8} $line_uri_bn."\n";
      }
      next;
    }elsif($line=~ /URI=\"([^\"]+)\"/){
      my $line_uri=$1;
      my $line_uri_bn=GetFileName($line_uri);
      if($line_uri_bn=~ /\.m3u8$/i){
        my ($m3u8_path_relative,$m3u8_path)=GetM3u8Path($line_uri,$dir_tmp);
        DownloadM3u8($line_uri,$m3u8_path,$ua,$dir_tmp);

        my $uri_quote=quotemeta($line_uri);
        $line=~ s/$uri_quote/$m3u8_path_relative/;
        #ToDo: Can I used URI for local file? I don't know.
        print {$fh_m3u8} $line."\n";
      }else{
        sleep(1);
        DownloadBinary($line_uri,File::Spec->catfile($dir_tmp,$line_uri_bn),$ua);
        my $uri_quote=quotemeta($line_uri);
        $line=~ s/$uri_quote/$line_uri_bn/;
        print {$fh_m3u8} $line."\n";
      }
      next;
    }else{
      print {$fh_m3u8} $line."\n";
      next;
    }
  }
  close($fh_m3u8);
}

sub DownloadBinary{
  my ($uri,$path,$ua)=@_;
  my $binary_res=$ua->get($uri);
  open my $fh_binary, '>', $path or die $!;
  binmode($fh_binary);
  print {$fh_binary} $binary_res->content;
  close($fh_binary);
}

sub GetM3u8Path{
  my ($m3u8_uri,$dir_tmp)=@_;
  my $filename_base=GetFileName($m3u8_uri);
  #$filename_base=~ s/\?.+$//;
  $filename_base=~ s/\.\w+$//;
  my $fn_w_ex=$filename_base.".m3u8";
  my $i=0;
  $filename_base=~ s/\..*?$//;
  while(1){
    my $fn_full=File::Spec->catfile($dir_tmp,$fn_w_ex);
    #my $fn_full=$fn_w_ex;
    if(-e $fn_full){
      $fn_w_ex=$filename_base.".".$i.".m3u8";
      $i++;
    }else{
      return ($fn_w_ex,$fn_full);
    }
  }
}

sub GetFileName{
  my ($file)=@_;
  $file =~ s/\?[^\?]+$//;
  $file =~ s/^.+\///;
#Added - may corrupt
  $file =~ s/\?.+$//;
  return $file;
}

sub DownloadFile{
  my ($vurl,$ua,$fh,$range_from,$session_uri,$session_id,$ping_content)=@_;
  my $dl_error="";
  my $dl_size=-1;
  my $dl_downloaded=0;
  my $last_ping=time;
  
  binmode($fh);
  
  my $downloder = sub {
    my ($data, $res, $proto) = @_;
    $dl_size=0+$res->headers->header('Content-Length') if defined $res->headers->header('Content-Length');
    die $dl_error="failed" if !$res->is_success;
    die $dl_error="aborted" if defined $res->headers->header('Client-Aborted');
    die $dl_error="died: ".$res->headers->header("X-Died") if defined $res->header("X-Died");
    $dl_downloaded+=length $data;
    print {$fh} $data;

    $last_ping = PingSession($ua,$session_uri,$session_id,$ping_content,$last_ping);
    };

  {
    my $request=HTTP::Request->new( GET => $vurl );
    if(defined($range_from) && $range_from != 0){
      $request->header(Range=>"bytes=".($range_from)."-");
    }
    
    my $res2=$ua->request( $request, $downloder);
    die "Failed: ".$res2->status_line if $res2->is_error;
  }
  
  if($dl_error ne ""){die $dl_error;}

  return ($dl_size,$dl_downloaded);
}

sub PingSession{
  my ($ua,$session_uri,$session_id,$ping_content,$last_ping)=@_;
  if(defined($session_uri) && time-$last_ping>40){
    my $ping_uri=$session_uri."/".$session_id."?_format=json&_method=PUT";
    
    my $request_option=HTTP::Request->new( "OPTIONS" , $ping_uri );
    $request_option->content($ping_content);
    $ua->request($request_option);
    
    $ua->post($ping_uri, Content => $ping_content);
    return time;
  }else{
    return $last_ping;
  }
}

sub GetInfo{
  my $info;
  my ($ua,$video_id,$chid)=@_;
  eval{
    my $info_res = $ua->get("https://www.nicovideo.jp/watch/".$video_id);
    my $info_json = scraper {
      process 'div#js-initial-watch-data', 'json' => '@data-api-data';
    }->scrape($info_res->content)->{json};
    if(! defined($info_json) || ! defined($info_res->content) || $info_json eq "" ){return;}
    #$info_json = unescape($info_json);
    $info = decode_json( $info_json );
  };
  if($@ || ! defined($info)){
    warn "GetInfo failed. Channel:$chid Id:$video_id\n";
    warn "ERROR: $@\n" if($@);
    return;
  }
  return $info;
}

sub GetHtml5VideoJson{
  my ($info,$ua) = @_;
  #if(!defined($info->{video}->{dmcInfo}->{session_api})){return;}
  #my $url=$info->{video}->{dmcInfo}->{session_api}->{urls}[0]->{url};
  if(!defined($info->{media}->{delivery}->{movie}->{session})){return;}
  my $url=$info->{media}->{delivery}->{movie}->{session}->{urls}[0]->{url};
  my $dsr = GetDmcSessionRequest($info);
  my $res = $ua->post($url."?_format=json", Content => $dsr);
  my $json = decode_json($res->content);
  return ($json,$url);
}

sub EscapeJson{
  my ($data) = @_;
  if(! defined($data)){return "";}
  $data =~ s/\\/\\\\/g;
  $data =~ s/\"/\\\"/g;
  $data =~ s/\n/\\n/g;
  $data =~ s/\r/\\r/g;
  $data =~ s/\t/\\t/g;
  return $data;
}

sub GetDmcSessionRequest{
  my ($info) = @_;
  
  my $protocol_parameters;
  
  if(! defined($info->{media}->{delivery}->{encryption})){
    $protocol_parameters=<<"EOF";
            "http_output_download_parameters": {
              "use_well_known_port": "@{[$info->{media}->{delivery}->{movie}->{session}->{urls}[0]->{isWellKnownPort}==1?"yes":"no"]}",
              "use_ssl": "@{[$info->{media}->{delivery}->{movie}->{session}->{urls}[0]->{isSsl}==1?"yes":"no"]}",
              "transfer_preset": ""
            }
EOF
  }else{
    #my $json_in=encode_json($info->{media}->{delivery}->{encryption});
    $protocol_parameters=<<"EOF";
            "hls_parameters": {
              "use_well_known_port": "@{[$info->{media}->{delivery}->{movie}->{session}->{urls}[0]->{isWellKnownPort}==1?"yes":"no"]}",
              "use_ssl": "@{[$info->{media}->{delivery}->{movie}->{session}->{urls}[0]->{isSsl}==1?"yes":"no"]}",
              "transfer_preset": "",
              "segment_duration": 6000,
              "encryption": {
                "hls_encryption_v1": {
                  "encrypted_key": "@{[$info->{media}->{delivery}->{encryption}->{encryptedKey}]}",
                  "key_uri": "@{[$info->{media}->{delivery}->{encryption}->{keyUri}]}"
                }
              }
            }
EOF
  }
  
  return <<"EOF";
{
  "session": {
    "recipe_id": "@{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{recipeId}) ]}",
    "content_id": "@{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{contentId}) ]}",
    "content_type": "movie",
    "content_src_id_sets": [
      {
        "content_src_ids": [
          {
            "src_id_to_mux": {
              "video_src_ids": [
                "@{[ 
join('", "',@{$info->{media}->{delivery}->{movie}->{session}->{videos}})
]}"
              ],
              "audio_src_ids": [
                "@{[
join('", "',@{$info->{media}->{delivery}->{movie}->{session}->{audios}})
]}"
              ]
            }
          }
        ]
      }
    ],
    "timing_constraint": "unlimited",
    "keep_method": {
      "heartbeat": {
        "lifetime": 120000
      }
    },
    "protocol": {
      "name": "http",
      "parameters": {
        "http_parameters": {
          "parameters": {
${protocol_parameters}
          }
        }
      }
    },
    "content_uri": "",
    "session_operation_auth": {
      "session_operation_auth_by_signature": {
        "token": "@{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{token}) ]}",
        "signature": "@{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{signature}) ]}"
      }
    },
    "content_auth": {
      "auth_type": "ht2",
      "content_key_timeout" : @{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{contentKeyTimeout}) ]},
      "service_id": "nicovideo",
      "service_user_id": "@{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{serviceUserId}) ]}"
    },
    "client_info": {
      "player_id": "@{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{playerId}) ]}"
    },
    "priority": @{[ EscapeJson($info->{media}->{delivery}->{movie}->{session}->{priority}) ]}
  }
}
EOF
}
