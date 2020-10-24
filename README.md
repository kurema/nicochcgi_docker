# nicochcgi
ニコニコチャンネルの自動キャッシュサーバー

## About
ニコニコチャンネルを監視して、ダウンロードするツールです。  
ダウンロードスクリプトに管理用のcgi、API、プレイヤー、テレビ向けUI等含めます。

## Demonstration
* [メインページ](https://nicocache.github.io/nicoch/)
* [TV向けUI](https://nicocache.github.io/nicoch/tv.html)
* [動画プレイヤー](https://nicocache.github.io/play.html#0)  

最新版とは限りません。静的サイト版。

## How to use
1. セットアップ
``` bash
$ git pull https://github.com/kurema/nicochcgi_docker.git
$ cd nicochcgi_docker
$ sudo docker-compose up -d
$ chown 666 config/*
$ chown 777 videos/*.sh
```

2. 基本設定
``` bash
$ sudo docker-compose exec nicochcgi perl /var/www/html/get_password.pl
$ nano config/nicoch.conf
```

設定変更用パスワード・ニコニコ動画のアカウント情報を設定します。  
設定変更用パスワードの初期値は``SyRDw3kGZ``です。  
hls暗号化対応設定を自身の責任で確認してください。

3. 自動ダウンロード
``` bash
$ sudo crontab -e
```

``` ctontab
0 3 * * * docker-compose exec nicochcgi perl /var/www/html/nico-anime.pl && docker-compose exec nicochcgi perl /media/niconico/mkthumb.sh
```

4. その他

キャッシュフォルダを移動させる場合は、docker-compose.ymlを編集してください。その際、mkthumb.shもコピーしてください。

## Apps
### [UWP版クライアント](https://www.microsoft.com/store/productId/9PFMPFTFX4W6)
Windowsで利用できるUWP版のクライアントがあります。

* [ストア](https://www.microsoft.com/store/productId/9PFMPFTFX4W6)
* [プロジェクトページ](https://github.com/kurema/NicochViewerUWP)

## Hints
* 動画一覧は単純にファイル構造を見て判断しています。
録画記録を保持しているわけではないので、適当な動画やチャンネルを削除しても問題ありません。
ただし、録画予約に残ったままなら再ダウンロードされます。
* ダウンロードフォルダは容量の大きいパーティションを指定する事をお勧めします。
minidlna等を設定するのもよいでしょう。

## Thanks
[Takumi Akiyama](https://github.com/akiym)様の[nico-anime.pl](https://gist.github.com/akiym/928802)がベースになっています。  
感謝します。  
