#!/usr/bin/perl
#use Net::Netrc;
use LWP::UserAgent;
use URI::Escape;
use CGI;
use Web::Scraper;
use Unicode::Escape qw(escape unescape);
use JSON;
use File::Spec;
use File::Basename;

require File::Spec->catfile(dirname(__FILE__),"common.pl");

print <<"HEAD";
Content-type: application/json
Access-Control-Allow-Origin: *

HEAD

#my $mach = Net::Netrc->lookup('nicovideo');
#my ($nicologin, $nicopassword, $nicoaccount) = $mach->lpa;

my %conf=GetConf("/etc/nicochcgi/nicoch.conf");
$nicologin = $conf{"niconico_id"};
$nicopassword=$conf{"niconico_password"};

my $login_info = {
    mail_tel => $nicologin,
    password => $nicopassword,
};

my $q=new CGI;
my $movie_id=$q->param('id');
#my $movie_id="DEBUG";

my $ua = LWP::UserAgent->new(cookie_jar => {});
$ua->post("https://secure.nicovideo.jp/secure/login?site=niconico", $login_info);


my $info_res = $ua->get("https://www.nicovideo.jp/watch/".$movie_id);
my $info_json = scraper {
  process 'div#js-initial-watch-data', 'json' => '@data-api-data'
}->scrape($info_res->content)->{json};
$info_json = unescape($info_json);
$info = decode_json( $info_json );

my $threadsUrl = ($info->{comment}->{nvComment}->{server})."/v1/threads";

my $post_msg=$info->{comment}->{nvComment};
delete $post_msg->{server};
my %emptyHash=();
$post_msg->{additionals}=\%emptyHash;

#DEBUG!
#print $threadsUrl;
#print "\n";
#print encode_json($post_msg);
#print "\n";

my $request_option=HTTP::Request->new( "OPTIONS" , $threadsUrl );
$request_option->header( "Origin" => "https://www.nicovideo.jp" );
$request_option->header( "Referer" => "https://www.nicovideo.jp/" );
$ua->request($request_option);

my $req=HTTP::Request->new(POST => $threadsUrl);
$req->header( "Origin" => "https://www.nicovideo.jp" );
$req->header( "Referer" => "https://www.nicovideo.jp/" );
$req->header( "x-client-os-type" => "others" );
$req->header( "x-frontend-id" => "6" );
$req->header( "x-frontend-version" => "0" );
$req->content(encode_json($post_msg));
print $ua->request($req)->content;

