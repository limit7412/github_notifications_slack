#!/bin/bash

region="ap-northeast-1"
container="github_notifications_slack_local"

docker build -t $container .                                  &&\
docker run --name $container -d $container /bin/sh            &&\
docker cp $container:/work/bootstrap .                        &&\
docker rm $container                                          &&\
sls invoke local --docker -f github_notifications_slack -d {}