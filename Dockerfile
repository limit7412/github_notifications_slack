FROM ruby:2.5.1

# ADD ./ /app

WORKDIR /app
RUN gem install bundler
EXPOSE 80
RUN bundle install --path ./bundle

CMD ["bundle","exec","ruby","src/app.rb","-p","80","-o","0.0.0.0"]
