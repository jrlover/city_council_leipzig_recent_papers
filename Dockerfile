FROM ruby:2.7
RUN apt-get update -qq
RUN apt-get install -y build-essential libpq-dev

ENV app /app
RUN mkdir $app
WORKDIR $app

ENV BUNDLE_PATH /box

ADD . $app

RUN bundle update --all
RUN bundle install

ENTRYPOINT bundle exec ruby 
CMD ["scraper.rb", "https://ratsinfo.leipzig.de/bi/vo020.asp?VOLFDNR=1003952"]
#CMD ["scraper_persons.rb", "https://ratsinfo.leipzig.de/bi/pa021.asp"]