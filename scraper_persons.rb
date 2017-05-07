require 'rubygems'
require 'scraperwiki'
require 'nokogiri'
require 'yaml'
require 'html_to_plain_text'
require 'active_support/core_ext/string'
require 'httpclient'
require 'json'

module Scraper
  module_function

  def config
    @config ||= YAML.load(File.read('./config_persons.yml'))
  end

  def expand_uri(path)
    "#{config['base_uri']}/#{path}"
  end
end


class Page < Struct.new(:uri)
  def doc
    @doc ||= begin
      puts "Load #{self.class} from #{uri}"
      Nokogiri::HTML(scrape(uri))
    end
  end

  def scrape(url, params = nil, agent = nil)
    if agent
      client = HTTPClient.new(:agent_name => agent)
    else
      client = HTTPClient.new
    end
    client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    client.receive_timeout=500
    if HTTPClient.respond_to?("client.transparent_gzip_decompression=")
      client.transparent_gzip_decompression = true
    end

    if params.nil?
      html = client.get_content(url)
    else
      html = client.post_content(url, params)
    end

    unless HTTPClient.respond_to?("client.transparent_gzip_decompression=")
      begin
        gz = Zlib::GzipReader.new(StringIO.new(html))
        return gz.read
      rescue
        return html
      end
    end
  end

end


class PersonIndex < Page
  def persons
    rows = doc.css('table.tl1 tr')
    rows = rows.take(Scraper.config['persons_limit'])
    rows.map! do |row|
      parse_row_to_person(row)
    end
    rows.compact!
    rows
  end

  private

  # extrahiert daten aus einer einzelnen tabellenzeile
  def parse_row_to_person(row)
#    # FIXME: Remove cowardice conditionals
    cells = row.css('td')
    return nil if cells.nil? || cells[2].nil?
    personUrl = Scraper.expand_uri(cells[2].css('a').first['href'])
    #print "cells: #{personUrl}\n"
    completeName = extract_text(cells[2])
    nameParts = completeName.split(",").map(&:strip)
    primaryNameParts = nameParts[0].split(" ")
    addressStrs = [ "Oberbürgermeister" ]
    acadStrs = [ "Prof.", "Dr." ]
    formOfAddress = nil
    title = nil
    familyNameParts = []
    primaryNameParts.each do |primaryNamePart|
      if addressStrs.include? primaryNamePart 
        formOfAddress = primaryNamePart
        next
      end
      if acadStrs.include? primaryNamePart 
        title = primaryNamePart
        next
      end
      familyNameParts.push(primaryNamePart)
    end  
    familyName = familyNameParts.join(" ")
    Person.new(personUrl, attributes: {
      body: Scraper.config['body'],
      name: completeName,
      title: title,
      formOfAddress: formOfAddress,
      familyName: familyName,
      givenName: nameParts[1],
      status: extract_text(cells[3]),
      #funktion: extract_text(cells[4]),
      # TODO create real membership objects
      membership_party: extract_text(cells[5]), 
      membership_council_since: extract_text(cells[6])  
    })
  end
  
  
class Person < Page
  def initialize(uri, attributes: {})
    super(uri)
    @predefined_attributes = attributes
  end
  
  def scraped_at
    Time.now
  end
  
  def attributes
      @attributes ||= {
        id: uri,
        url: uri,
        scraped_at: scraped_at,
      }.merge!(@predefined_attributes)
    end
end

  # extrahiert den text aus den tabellenzellen
  def extract_text(cell)
    return nil if cell.nil?
    cell.text
  end
end

ScraperWiki.config = { db: 'data.sqlite' }

index = PersonIndex.new(Scraper.expand_uri(Scraper.config['persons_path']))
index.persons.each do |person|
  person.attributes
  print "atts: #{person.attributes}\n"
  ScraperWiki.save_sqlite([:id], person.attributes, 'data')
end