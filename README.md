# github_notifications_slack
[![serverless](https://github.com/limit7412/github_notifications_slack/actions/workflows/serverless-prod.yml/badge.svg?branch=master)](https://github.com/limit7412/github_notifications_slack/actions/workflows/serverless-prod.yml)

  - githubのアカウントの通知をslackで流したい
  - crystal
  - aws lambda
  - serverless framework

```
WEBHOOK_URL: <通知用webhook>
ALERT_WEBHOOK_URL: <アラート用webhook>
GITHUB_TOKEN: <token>
SLACK_ID: <通知先ユーザーid>
ENV: <環境名>
```