# title

こんにちは。MIXI 開発本部 SRE グループの [riddle](https://twitter.com/riddle_tec) です。

最近インフラ・SRE の領域から Go のバックエンドエンジニアも担当するようになりました。

情報発信も好きなのでブログを書きたいなと思っていたのですが、「記事に書けるネタがない！！」ということに気づきました。ということで、 **「バックエンドエンジニアの仕事で記事を書くことが難しくなった理由」** と **「解消法」** を考えてみます。

## 以前は何を書いていたのか？

今まではこういう記事を書いていました。

- [Bazel とお別れして make  を使いはじめた話](https://mixi-developers.mixi.co.jp/byebye-bazel-welcome-make-b966bfd37fce)
- [Ingress が 200 個を超えたら構築に 3 時間かかりはじめたので Gateway API を検証したけどまだ早かった話](https://mixi-developers.mixi.co.jp/ingress-to-gateway-b399cd2747a9)
- [スマホゲームのゴーストスクランブルの裏側を支える技術](https://mixi-developers.mixi.co.jp/stble-over-view-ab9bc69f5819)

どれも我々のシステムの独自問題を解消する話ではありますが、一般的なツールの利用の仕方や、利用時の課題について紹介していたので似たシチュエーションであれば参考になるかなと思います。

## バックエンドエンジニアで日々解決する課題

バックエンドエンジニアとしてドメインの開発に携わると、ドメイン固有の機能の開発やバグの修正に多くの時間を費やすことになります。

しかし、これらはプロダクトやサービスに深く依存するため、背景や状況、組織体制やチームのレベルなどによって最適解が違います。これらの理由を含めるて記事を書くと情報量が多くなり、伝えるのが難しくなります。受け手にとっては前提が多く理解し辛いでしょう。

そのため、ドメイン固有の内容は外部に発信することが困難になります。また、ドメインに深く関わるため、情報の秘匿性の観点からも発信が好ましくないケースもあります。たとえば、特許やセキュリティに絡む内容などがそうです。

## それでも情報を何とか発信するには

そこで、**情報を抽象化すること** が重要になります。

たとば、以下の内容は特定のシステムに依存していません。

- アルゴリズムやデータ構造などにフォーカスし、それを変更した話にする
- 一般的なセキュリティ対策までぼかして紹介する
- 導入したツール、ライブラリの話をする

これをうまくやるためには、**「アナロジー思考」** という考え方が役立ちます。

## アナロジー思考とは

> アナロジーとは日本語では「類推」のことです。
> つまり「類似しているものから推し量る」ということです。
>
> 身近な例でいけば、「たとえ話」というのもアナロジー思考の典型的な応用例ということになります。
> 人間は新しい経験をするときにでも無意識のうちに昔の経験から類推して物事を考えます。
>
> [「アナロジー思考」――新しいアイデアは「遠くから借りてくる」？](https://mag.executive.itmedia.co.jp/executive/articles/1110/06/news009.html#:~:text=%E3%82%A2%E3%83%8A%E3%83%AD%E3%82%B8%E3%83%BC%E6%80%9D%E8%80%83%E3%81%A8%E3%81%AF%E3%80%81%E3%80%8C%E9%AB%98%E5%BA%A6%E3%81%AA%E3%83%91%E3%82%AF%E3%83%AA%E3%80%8D%E3%81%AE%E3%81%93%E3%81%A8&text=%E8%BA%AB%E8%BF%91%E3%81%AA%E4%BE%8B%E3%81%A7%E3%81%84%E3%81%91,%E3%81%A6%E7%89%A9%E4%BA%8B%E3%82%92%E8%80%83%E3%81%88%E3%81%BE%E3%81%99%E3%80%82)

アナロジー思考を鍛えることで、具体的な事例からエッセンスを抜き出して抽象化ができるようになり、問題の解決方法を別の分野から借りられたりします。

この方法を自分が対応した問題に対しても適用し、（情報発信の意味があるレベルまで）抽象化して発信することができそうです。

この本が詳しく紹介してくれてるので、ぜひどうぞ。
![picture 1](images/8390b796e7aa6b7b6f78b95a560627de18c9271222d36fb020809923f455d01b.png)

## まとめ

多くのソフトウェアエンジニアが日々、ドメイン固有の問題と戦っています。
しかし、この情報は伝えづらく、技術ブログを読む側からすると存在さえもわかりにくいものです。

情報を受け取る側は、「会話における余白」や「言外のもの」に近い業務が多いことを意識して、
情報を発信する側は、そういった情報をうまく噛み砕いて発信するよう心がけると良いでしょう。
