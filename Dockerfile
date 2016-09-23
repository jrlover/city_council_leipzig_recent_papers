FROM ruby:2.2.1
RUN apt-get update -qq
RUN apt-get install -y build-essential libpq-dev

ENV app /app
RUN mkdir $app
WORKDIR $app

ENV BUNDLE_PATH /box

ADD . $app

RUN bundle install

ENTRYPOINT bundle exec ruby scraper.rb
CMD ["https://ratsinfo.leipzig.de/bi/vo020.asp?VOLFDNR=1003952"]