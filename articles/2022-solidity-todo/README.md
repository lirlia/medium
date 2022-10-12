# Solidity で TODO リストを作ってみた

こんにちはMIXI 開発本部 SREグループ の [riddle](https://twitter.com/riddle_tec) です

今回は Solidity の理解を深めるために Ganache / Truffle / Solidity で簡単な TODO リストを実装してみました。

デモ
![preview](images/preview.gif)

コード: [lirlia/solidity-todo](https://github.com/lirlia/solidity-todo)

---

データベースと異なりブロックチェーンはすべての変更に対してユーザに費用が発生するため、内容を変えたり・クローズしたり・削除したりなど変更が大量に発生する TODO リストとは **非常に相性が悪い** です。

デモを見ると作成や削除のたびに `MetaMask` が起動して、毎回 **Ethereum の支払いが発生**しています。(要するに何かをするたびにお金を払っている状況)

TODO リストにアイテムを追加するだけでお金を取られるのはたまったもんじゃないので現実的に使い道はなさそうです。ただ簡単な CRUD 操作を Solidity で実践する意味ではためになったのでぜひみなさんもやってみてください！

以下は簡単なコードの解説です。

## コードの解説

```solidity
contract todo {

  struct Todo {
    string contents;
    bool is_opened;
    bool is_deleted;
  }

  Todo[] public todos;
```

ここでは `Todo` で使用するアイテムの構造体を宣言しています。TODO アイテムの内容とアイテムがオープンかどうか(HTML上でチェックの有無を操作する)、削除されているかを項目として用意しています。

ブロックチェーンでは一度追加した値はすべて記録されてしまいます。そのため削除した TODO アイテムも返ってきてしまうので、削除フラグが `true` の変数をコントラクトでは返却しないことで削除のような処理を実現しています。

```solidity
  // id と address の紐付け
  mapping (uint => address) public todoToOwner;
  mapping (address => uint) todoCountByOwner;
```

ここは対象の TODO アイテムが誰のものか？何個持っているのか？を扱う変数の定義をしています。

```solidity
  // 自分のものだけ作業できるようにする
  modifier onlyMine(uint id) {
    require(todoToOwner[id] == msg.sender);
    _;
  }
```

ここでは後々に出てくる関数で **自分の TODO アイテムしか操作できないようにする条件** を定義しています。

```solidity
  // すべての TODO を返却する
  function getTODO() external view returns(uint[] memory) {

    // TODO の数が 0 ならからの配列を返す
    if (todoCountByOwner[msg.sender] == 0) {
      uint[] memory emptyArray = new uint[](0);
      return emptyArray;
    }

    // array は memory か storage か設定しないと駄目
    uint[] memory result = new uint[](todoCountByOwner[msg.sender]);
    uint counter = 0;

    for (uint i = 0; i < todos.length; i++) {
      if (todoToOwner[i] == msg.sender && todos[i].is_deleted == false) {
        result[counter] = i;
        counter++;
      }
    }

    return result;
  }
```

`getTODO` ではコントラクトにアクセスしてきたユーザの TODO アイテムの一覧を返却します。本当は `Todo` 構造体の配列を返却したかったのですが、ぱっと調べた限りでは独自の構造体の配列を返却できないため**配列のインデックスのみを返却**しています。（良いやり方があれば教えて下さい！）

そのためフロントエンドからインデックスを使ってブロックチェーンに問い合わせ、詳細な TODO アイテムの情報を取得しています。

```solidity
  // 引数から TODO を作成し storage に保存する
  function createTODO(string memory _contents) public returns(uint) {
    todos.push(Todo(_contents, true, false));
    uint id = todos.length - 1;
    todoToOwner[id] = msg.sender;

    // TODO 数を増やす
    todoCountByOwner[msg.sender]++;

    return id;
  }

  function updateTODO(uint _id, bool _is_opened) public onlyMine(_id) {
    // 指定の id の TODO をアップデートする
    todos[_id].is_opened = _is_opened;
  }

  function deleteTODO(uint _id) public onlyMine(_id) {
    require(todos[_id].is_deleted == false);

    // 自分の TODO を削除する
    todos[_id].is_deleted = true;

    // TODO 数を減らす
    todoCountByOwner[msg.sender]--;
  }
}
```

TODO アイテムの作成・更新・削除を行う関数です。あまり特筆することもありませんが、いずれもブロックチェーンに書き込みを伴う処理のため実行には GAS 代がかかるのが注意点ですね。
