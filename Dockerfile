FROM crystallang/crystal:latest

COPY ./ /app

WORKDIR /app
RUN shards install
RUN crystal build ./src/github_notifications_slack.cr --release
RUN chmod 755 ./github_notifications_slack

CMD ["./github_notifications_slack", "-c"]
