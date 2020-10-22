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
[Packages](https://github.com/kurema/nicochcgi_docker/packages/469453)参照。

1. Dockerで動かす。
2. 設定を変更(パスワード編集)。
3. crontabを組む。

## play.html
簡単なニコニコ動画のhtmlプレイヤーが含まれています(play.html)。  
同様のニコニコ動画キャッシュサーバーを作る際には手軽なのでお勧めです。

注意点
1. play.htmlはCSSやjavascript含めてスタンドアローンです。
2. コメント取得はサーバー側でプロキシを建てています。動画のやコメントプロキシのUrl指定部分は書き換えてください。
3. コメント表示の挙動がいくらか異なります。簡易版と考えてください。またちょっと重いです。
4. フォントサイズは基本的に実際より小さめにしています。現在としては公式のサイズは大きめだと個人的に思います。

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
