FROM crystallang/crystal:latest as build-image

WORKDIR /work
COPY ./ ./

RUN crystal build --link-flags -static -o bootstrap src/main.cr
RUN chmod +x bootstrap

# FROM public.ecr.aws/lambda/provided:al2

# COPY --from=build-image /work/ /var/runtime/

# CMD ["github_notifications_slack"]
