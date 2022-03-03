# 独自トークンを賭けてじゃんけんをするDappsを作った

こんにちはミクシィの 開発本部 SREグループ の [riddle](https://twitter.com/riddle_tec) です。

今回はスマートコントラクトと Dapps の理解度を高めるために、独自トークンを賭けてじゃんけんをするアプリを作ってみましたので紹介します。

### 目次

## 作ったもの

**動作イメージ**

![picture 17](https://raw.githubusercontent.com/lirlia/medium/main/articles/202203-janken//images/85eb5be2-e6fd-4e47-90b8-dfc9d3597be9.gif)

**遊び方**

- Chrome Addon で Metamask をインストールする
- Metamask にログインする
- 使用するネットワークを `Ropsten テストネット` にする
- `Ropsten テストネット` の ETH を faucet サイトで取得する
  - [Ropsten testnet faucet](https://faucet.egorfine.com/)
- [じゃんけん](https://lirlia.github.io/Rock-paper-scissors-ethereum/) にアクセスして、右上の仮想通貨のアイコンをクリックし`RSPトークン` をチャージする。
- トークンがチャージされたら好きな手を選んでじゃんけんをする


## 作ったことで得られたもの

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/202203-janken//images/11beb0b14ffabc1db66ecfe1b18798163183d194441c842a0e963a899dd18037.png)  

**じゃんけん Dapps** を通じてこんなことが学べました。

- 独自トークンの発行 / 独自トークンによるゲームプレイ
- 疑似乱数(完全なランダムではない)の作成方法
- event による通知（とフロントエンドでのキャッチ）
- `ether.js` の使用感（これまで `web3.js` しか使わなかったので)
- `Hardhat` を利用したローカル開発とテストの実施(これまで `truffle/Ganache` を使ってた)
- `Remix` をつかった `Ropsten テストネット`へのデプロイ(これまでローカルでのみやってた)
- GitHub Pages を使った公開
- Solidity のテストコード作成

「なんとなくこうだろうなあ〜」と思っていたことが実際の作業を通じて身についたの点がよかったですね。

作ってみてわかったこととしては、

- テストネットでのトランザクションは実行までに時間がかかるので、**じゃんけんの結果がでるまで下手すると数十秒かかる**。ラグがあっても許される環境でしか使い道がない。(もしくは高速なチェーンを使わないと駄目)
- `payable` 関数は各ブロックチェーンの通貨を支払う場合にしか使えず**独自トークンでの支払はできない**

などでしょうか。

## 次にやりたいこと

![picture 2](https://raw.githubusercontent.com/lirlia/medium/main/articles/202203-janken//images/676e3d29d1973ee0783a71e881ca59a024c0c5bf7d7f032a99d3ab4bc3779954.png)  

一通り動いて遊べる？ものが公開できたので、次はより運用のしやすさを目指したいと思います。作りながらドキュメントなどを読んでいてピックアップしたのがこちらです。

- ether.js は ABI を [Human-readable にできる](https://docs.ethers.io/v5/api/utils/abi/formats/#abi-formats--human-readable-abi)とのことなので試してみる
- Proxy コントラクトの場合、[デプロイ後にコントラクトをバージョンアップできる](https://eips.ethereum.org/EIPS/eip-2535)そうなので試してみる
- コントラクトをアドレスで指定しているがドメイン名のように [ENS(Ethereum Network Service)](https://docs.ens.domains/dapp-developer-guide/ens-enabling-your-dapp) による名前解決ができるらしいので試してみる
- TypeScript でテストコードが書けるらしいので試してみる
- [VRF](https://docs.chain.link/docs/get-a-random-number/) を使うことで本当のランダム値が取得できるらしいので試してみる

## じゃんけんコードの解説

![picture 4](https://raw.githubusercontent.com/lirlia/medium/main/articles/202203-janken//images/0d2690b4f410c69c5ab3c001e5520e2456cf822bbbc4c61d807599bc9d1656c0.png)  

残りは今回のコードについて Solidity 部分を解説します。

最初は普通の定義ですね。

RSP(`RockScissorsPaper`)トークンという独自のERC20トークンを発行するため `OpenZeppelin` の実装を継承しています。これを使うだけで独自トークンを発行できるので非常に便利です。

`constructor() ERC20("Janken", "RSP") {}` だけで **RSP トークン**が使えるようになる… (すごい)

```solidity
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "./base.sol";

contract Rsp is Base, ERC20 {

    mapping(address => Score) public scoreOfOwner;

    constructor() ERC20("Janken", "RSP") {}
```

`event` はフロントエンド側に通知するためのイベント処理です。具体的には **じゃんけん結果が出た場合**や、**トークンが付与された場合**に発動します。

```solidity
    event TokenNotification(uint token);
    event ResultNotification(Results result, uint earnToken, uint totalToken, Hands playerHand, Hands cpuHand, Score score);
```

ここから実際にじゃんけんをする処理です。複雑なことはしていません。

- ランダムに CPU の手を生成 (`_random` / `_generateHand`)
- プレイヤーと CPU の手を比較 (`_checkResult`)

```solidity
    function _random(uint mod) internal view returns(uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % mod;
    }

    // CPU のじゃんけんの手を生成する
    function _generateHand() internal view returns(Hands) {
        return Hands(_random(3));
    }

    // じゃんけんの手を比較して判定を行う
    function _checkResult(Hands player, Hands computer) internal pure returns(Results) {
        // draw
        if (player == computer) { return Results.Draw; }

        // win
        if (player == Hands.Rock && computer == Hands.Scissors) { return Results.Win; }
        if (player == Hands.Paper && computer == Hands.Rock) { return Results.Win; }
        if (player == Hands.Scissors && computer == Hands.Paper) { return Results.Win; }

        // lose
        return Results.Lose;
    }
```

改良ポイントとしては `_generateHand` 関数ではブロックのタイムスタンプや難易度、送信者のアドレスを使ってランダム値を生成している箇所でしょうか。以下の記事でも解説されていますが、マイナーは任意の結果がでるまでブロックの生成＋トランザクションの生成を行うことで**いい結果だけを公開**できてしまいます。(要するに脆弱性がある)

- [SolidityとBlockchainで真に乱数を生成する方法](https://ichi.pro/solidity-to-blockchain-de-shinni-ransu-o-seiseisuru-hoho-172543406431199)
- [Shardingなどで使う乱数をブロックチェーンで実現するには | Stir Lab](https://lab.stir.network/2019/03/27/randomness-in-blockchain/)

Ethereum では [VRF](https://docs.chain.link/docs/get-a-random-number/) を使うと厳密なランダム値が取得できるとのことなので次回はこっちを試そうと思います。

---

続いて **RSP トークン**をミントしたり払い戻す処理ですね。ここも大した処理はしていません！

```solidity
    // トークンをあげる
    // ※実際はこんなことをやってはいけない
    function getToken() external {
        _mint(msg.sender, 100 ether);
        emit TokenNotification(balanceOf(msg.sender));
    }

    // 掛け金の2倍の token を払い戻す
    function _sendRewardToken(uint token) internal returns(uint) {
        token = token * 2;
        _mint(msg.sender, token);
        return token;
    }
```

ここがメインの処理です。ここまでで紹介した各関数をコールしてゲームを提供しています。(`Hardhat` を使うと `console.log` でログを発行できるので非常に重宝しています)

```solidity
    // じゃんけんを行う
    function doGame(Hands playerHand, uint token) external {
        console.log("bet: '%d / wallet: '%d'",
            uint(token),
            uint(balanceOf(msg.sender))
        );
        require(token > 0, "token is under 0, must be set over 0");
        require(token <= balanceOf(msg.sender), "don't have enough token");

        // cpu の手を生成
        Hands cpuHand = _generateHand();

        // じゃんけん結果を出力
        Results result = _checkResult(playerHand, cpuHand);

        uint earnToken = 0;
        if (result == Results.Win) {
            // player が勝利した場合は 2倍の token を渡す
            earnToken = _sendRewardToken(token);
            scoreOfOwner[msg.sender].winCount++;

        } else if (result == Results.Lose) {
            // 負けた場合は掛け金を没収する
            transfer(address(this), token);
            scoreOfOwner[msg.sender].loseCount++;

        } else if (result == Results.Draw) {
            scoreOfOwner[msg.sender].drawCount++;
        }

        console.log("player hand: '%d / computer hand: '%d' / result: '%d'",
            uint(playerHand),
            uint(cpuHand),
            uint(result)
        );

        emit ResultNotification(result, earnToken, balanceOf(msg.sender), playerHand, cpuHand, scoreOfOwner[msg.sender]);
    }
}
```

## さいごに

![picture 5](https://raw.githubusercontent.com/lirlia/medium/main/articles/202203-janken//images/4d07fe670d4d363596c8d2f981cf5eaaf5ea56ac9728da5bbb955ddcc0541c7e.png)  

独自トークンを受け渡す以外は**じゃんけんを実装しただけ**なので Solidity であっても比較的受け入れやすいかなと思います。

ブロックチェーンを使うこと以外は割とシンプルな言語・仕組みだと思いますので、よろしければ挑戦してみてください！

- [じゃんけん on Ethereum](https://lirlia.github.io/Rock-paper-scissors-ethereum/)
