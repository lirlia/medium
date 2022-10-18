# title

こんにちは。MIXI 開発本部 SREグループの [riddle](https://twitter.com/riddle_tec) です。

先日、Google Cloud Next '22 で行われた **「第 2 回 Game Engineers Meetup」** に登壇しました。

> Game Engineers Meetup は Google Cloud のサービスから Agones や Open Match といった Gaming OSS まで、ナレッジやユースケースの共有と、ユーザー同士の交流を目的にした Meetup です。

https://youtu.be/NGME7f6F50g

大きいイベントに出させていただき貴重な経験ができたので、経緯や準備したことなどを紹介します！

# イベントに登壇する経緯

私の所属するチームでは Google Cloud の方にレビューやコンサルティングをお願いしています。
そのため、設計を共有している関係で我々が使っていた GKE + Agones が今回のイベントにピッタリだったので登壇の依頼をいただきました。

※出てくれませんか〜ぐらいのノリで来る
# 開催までにやったこと

登壇時のプレゼン資料を作成しました。
Google Cloud のイベントなので、向こうからいただいたテンプレートを使って資料を作っただけなので簡単でした。

↓実際に作った資料
![picture 1](images/f8cd708e34d27a248b1027271db372d7b906b6af739cd26d457923ece7998baf.png)  

ただ忘れちゃいけないのが **「社内の広報や知財のGoサインをいただくこと！」**
社外に出すのは色々気にしないといけないので大変ですね。

また今回はパネルディスカッションで合計4人(司会者を除く)で会話する形式だったので、質問したいことを事前に共有しておき当日あたふたしないようにしました。

## ついでに詳細な記事も書いた

何人かでパネルトークをする関係上「あまり説明の時間が取れない」とのことだったので、発表を補足する記事もあわせて書き上げて当日投稿できるようにしました。

https://mixi-developers.mixi.co.jp/stble-voicechat-with-agones-aec5cbebe4a4

記事を事前に書くと **「発表の時に説明したいこと」** や **「疑問点」** が色々と出てきますし、**「この順番で話せばいいな」** が何となく見えてくるのでオススメです！


# リハーサル

![picture 1](images/0bc0359d3db7e7b21aa74504b0cbdffa587301b5f25d6fe1b1764280331bf709.jpg)  

大きいイベントというだけあってリハーサルがちゃんとあります！すごい！

当日と同じように会場が設営され、進行の方や映像配信の方と一緒に当日の流れを確認していきます。

![picture 2](images/06465405473bc74b850a3bf8e7eba6a8e288b0cf513333d5210420f67ded912a.png)  

ここで分単位の細かいスケジュールや、動線の確認、椅子の位置、後日の録画配信を考慮した立ち位置などプロフェッショナルの仕事をみました。

イベントの裏側って色々あって大変なんだなあ・・・と実感。

## アメニティをもらう

「登壇時に着用してください」とTシャツをいただき

![picture 4](images/09b758d82b146c0f9ff2c1bd30decf6c865df6035ea16bf604287de2b8f314fc.jpg)  

よくあるシールももらいました。

![picture 3](images/a2c61275f80699ce168c2c3abbfc2669e94cf6a701517c14ea899004d0f3f584.jpg)  

イベント中は Mac のりんごマーク見えると **NG** ってことで、いただいたシールを貼るようにと言われたので貼ってます。

![picture 5](images/75a3770007445eb630c779506db1fd1fa53c159fe0c6839f273087e7d63812a3.png)  

またご時世ということで、当日に実施するコロナの抗原検査キットもいただきたイベント当日に確認しました。

![picture 6](images/1619e2ecb5a3c6aa9195d1555234129fdf58d964d2d220f1596c43471fc34733.jpg)  


# 開催当日


登壇の1時間ぐらい前に集合と言われていたので、受付をしてイベントの控室で待機していました。

![picture 6](images/IMG_8771.jpg)  

イベントには軽食や昼食もついていましたね（豪華）。

![picture 7](images/3df6c089a8bbe5f3295fe8746f6160615b8d8a6d400033a719ca6f36fbd3940a.jpg)  

![picture 8](images/f6b1bfefc84321437835e97bcdcad07a690aa728865821e3caa4018251558f56.jpg)  

そんなこんなでイベント開始です。

https://youtu.be/NGME7f6F50g

イベント開催タイミングに記事を Twitter で投稿してもらいました。
https://twitter.com/mixi_engineers/status/1580801072972505088?s=20&t=6SjefsPsYCBxa6XDHNroQg

# 打ち上げ

イベント終了後は Google 側で用意してくれたアフターパーティに参加しました。結

![picture 9](images/4068fed61e8f684df6e9db5d81740f21329e9850ec79921bc81d665cd05a8de6.jpg)  
![picture 10](images/64eaebcd9e07c0ea15c5f3433fd4668595eb3ecc550bf36f9e44869060bc0000.jpg)  
![picture 11](images/260dee972e5c6b5fd91ddab3d6851fd244e7fcb102323dd887a99e119c439622.jpg)  

構色々出してくれたので、これをいただきつつ登壇者と GKE + Agones 周りや、Google Cloud 周りの最近の話や情報交換をしていました。

# 最後に

イベント登壇を通じてわかったのは、オフラインイベントだと交流会を通じて他社の事情や違い、流行をを知れるのがいいですね。

今までたくさんのイベントに参加してきましたが、発表を聞くだけでその後の打ち上げで有意義な話をした経験がなかったので、今回のイベントはとても刺激になりました。

イベントの準備・参加はそれなりに大変でしたが、(他のテーマでも)ぜひ参加していきたいなと思いました。