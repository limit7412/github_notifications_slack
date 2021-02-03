FROM crystallang/crystal:latest as build-image

WORKDIR /work
COPY ./ ./

RUN crystal build --link-flags -static -o bootstrap src/main.cr
RUN chmod +x bootstrap