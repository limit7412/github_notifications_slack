# AGENTS

## review

Always review in Japanese.

## document / comment

レビューコメントやドキュメントなど日本語の文章を書くときは、`.claude/skills/japanese-tech-writing` の文章規範に従う。
読み物として読ませたい解説文を書くときは、あわせて `.claude/skills/cognitive-rhythm-writing` の緩急の規範を用いる。

## github

- 機能実装時はデフォルトブランチへのPRを作成する
- ある程度の単位でcommit、pushしPRとissueが存在すれば更新する
- PRに付いた指摘が無いか都度確認してあれば必要な対応か検討して、必要なら修正する
  - 付いた指摘に対してはcommit idをつけて返答をしてresolveする
- PRのスコープ外の問題が発覚した場合は別途issueを作成する
- issueの解決を目的とした場合は修正中都度issueの本文を更新し必要に応じてコメントをつける
