# github_notifications_slack
[![serverless](https://github.com/limit7412/github_notifications_slack/actions/workflows/serverless-prod.yml/badge.svg?branch=master)](https://github.com/limit7412/github_notifications_slack/actions/workflows/serverless-prod.yml)

  - githubのアカウントの通知をslack / discordで流したい
  - crystal
  - aws lambda
  - serverless framework

```
WEBHOOK_URL: <通知用webhook>
ALERT_WEBHOOK_URL: <アラート用webhook>
GITHUB_TOKEN: <token>
NOTIFY_MODE: <slack | discord（省略時 slack）>
ENV: <環境名>
```

## 通知先の切り替え

`NOTIFY_MODE` で通知・アラートの投稿先を切り替える。

- `slack`（既定）: `WEBHOOK_URL` / `ALERT_WEBHOOK_URL` に Slack Incoming Webhook を設定
- `discord`: 同変数に Discord Webhook URL を設定

## メンション

メンション対象の通知（mention 系 reason）とアラートは、チャンネル全体に通知する。
Slack では `@channel`（`<!channel>`）、Discord では `@everyone` を使うため、
ユーザー ID の設定は不要。

ただし PR の通知は、CI などの自動チェックが失敗中・実行中のあいだメンションしない。
レビューできる状態になっていない PR でチャンネル全体を叩かないため。
通知そのものは従来どおり届く。

## 投稿の分割

メンション対象の通知とそれ以外は、別々の投稿に分けて送る。
同じ投稿に混ざると、`@channel` が付いていても、どれが自分宛てなのかは投稿を開くまで
分からないため。

分けるのは投稿の区切りだけで、並べ替えはしない。
通知は更新時刻の昇順のまま届き、メンション対象が無ければ投稿は 1 つになる。

区切りの判定には reason だけを使う。
CI の状態でメンションが抑止された PR も、メンション対象の投稿に入る。
