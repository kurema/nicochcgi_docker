# nicochcgi
![Docker Container Build Workflow](https://github.com/kurema/nicochcgi_docker/workflows/Docker%20Container%20Build%20Workflow/badge.svg)

ニコニコチャンネルの自動キャッシュサーバー

## 概要
ニコニコチャンネルを監視して、ダウンロードするツールです。  
ダウンロードスクリプトに管理用のcgi、API、プレイヤー、テレビ向けUI等含めます。

[nicocache/nicochcgi](https://github.com/nicocache/nicochcgi)のDocker対応版で、現在こちらを主に開発しています。

[Qiita記事](https://qiita.com/kurema/items/795f547a5c105b73b792)

## デモ
* [メインページ](https://nicocache.github.io/nicoch/)
* [TV向けUI](https://nicocache.github.io/nicoch/tv.html)
* [動画プレイヤー](https://nicocache.github.io/play.html#0)  

最新版とは限りません。静的サイト版。

## 使い方
1. セットアップ
``` bash
$ git pull https://github.com/kurema/nicochcgi_docker.git
$ cd nicochcgi_docker
$ nano docker-compose.yml
$ sudo docker-compose up -d
$ chmod 666 config/*
$ chmod 777 videos/*.sh
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
0 3 * * * cd docker-compose.ymlの存在する場所 && docker-compose exec -T nicochcgi perl /var/www/html/nico-anime.pl >> ログファイル 2>&1 && docker-compose exec -T nicochcgi perl /media/niconico/mkthumb.sh >> ログファイル 2>&1
```

4. その他

* http://サーバー名:50001/ でアクセスできます。録画予約→一括編集、でキャッシュするチャンネルを登録します。
* キャッシュフォルダを移動させる場合は、docker-compose.ymlを編集してください。その際、mkthumb.shもコピーしてください。
* 単純にキャッシュフォルダをファイル共有しても良いでしょう。

## 標準版との違い
* ニコニコアカウント情報がnicoch.conf内に移動
* 標準で操作パスワードを追加
* 設定を同一フォルダ内から``/etc/nicochcgi``に移動

以上の違いだけで、Docker環境でなくとも概ね同様に使えます。

## アプリ
### [UWP版クライアント](https://www.microsoft.com/store/productId/9PFMPFTFX4W6)
Windowsで利用できるUWP版のクライアントがあります。

* [ストア](https://www.microsoft.com/store/productId/9PFMPFTFX4W6)
* [プロジェクトページ](https://github.com/kurema/NicochViewerUWP)

## スクリーンショット
![](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/146467/e56f9df6-48ac-58af-e8f1-967b3d4790d6.png)

## 謝辞
[Takumi Akiyama](https://github.com/akiym)様の[nico-anime.pl](https://gist.github.com/akiym/928802)がベースになっています。  
感謝します。  

2024年の仕様変更対応では[AlexAplin](https://github.com/AlexAplin)様の[nndownload](https://github.com/AlexAplin/nndownload)を参照させていただきました。感謝いたします。
