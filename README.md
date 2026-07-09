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
MENTION_ID: <メンション先ユーザーid（Slackなら U...、Discordならユーザーid）>
NOTIFY_MODE: <slack | discord（省略時 slack）>
ENV: <環境名>
```

## 通知先の切り替え

`NOTIFY_MODE` で通知・アラートの投稿先を切り替える。

- `slack`（既定）: `WEBHOOK_URL` / `ALERT_WEBHOOK_URL` に Slack Incoming Webhook を設定
- `discord`: 同変数に Discord Webhook URL を設定

メンション先は `MENTION_ID` で指定する。Slack と Discord で ID 体系が異なるため、
モードに合わせた ID を設定する。後方互換として `MENTION_ID` 未設定時は `SLACK_ID` を使う。
