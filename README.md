# FutsalTeamMaker (PoC)

フットサルのイベント・大会の主催者向けに、参加者の実力が均等になるようにチームを分ける iOS アプリの PoC です。

## できること

- 選手を名前と実力（1〜5）で選手名簿に登録する（端末内に保存。サーバーは使いません）
- 大会・イベントごとにフォルダを作り、名簿からメンバーを選ぶ
  - 新しい大会を作るときは、前回の大会のメンバーをそのまま引き継げる
  - ほかの大会のメンバーをまとめて追加することもできる
  - 名簿で実力を直すと、その選手が入っているすべての大会に反映される
- 大会のメンバーのうち今回参加する選手にチェックを入れ、チーム数（2〜8）を選んで分ける
- 各チームの人数・実力の合計・平均と、チーム間の合計の差を表示する
- 「分け直す」で、同じくらい均等な別の組み合わせを出す
- 結果を LINE などに貼れるテキストで共有する（実力は載せません）

## チーム分けの方法

`FutsalTeamMaker/Domain/TeamBalancer.swift`

1. 実力の高い順（同じ実力の中はランダム）に、空きのあるチームのうち合計が一番低いチームへ入れる
2. 2チーム間で1人ずつ入れ替え、合計のばらつきが小さくなるかぎり入れ替えを続ける
3. 1〜2 を40回試し、合計の差が一番小さかった結果の中からランダムに1つ選ぶ

人数はチーム間で最大1人までしか差が出ません。

## 開発環境

- Xcode 26 / iOS 17 以上 / SwiftUI + SwiftData
- プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成します（`.xcodeproj` はリポジトリに入れていません）

```sh
xcodegen generate
open FutsalTeamMaker.xcodeproj
```

テスト（Swift Testing）:

```sh
xcodebuild test -project FutsalTeamMaker.xcodeproj -scheme FutsalTeamMaker -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 今回のPoCで見送ったこと

- スコアボード
- 日程調整・出欠管理（サーバーが必要になるため）
