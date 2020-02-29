require 'rubygems'
require 'scraperwiki'
require 'nokogiri'
require 'yaml'
require 'html_to_plain_text'
require 'active_support/core_ext/string'
require 'httpclient'
require 'json'
require 'sqlite3'

module Scraper
  module_function

  def config
    @config ||= YAML.load(File.read('./config.yml'))
  end

  def expand_uri(path)
    "#{config['base_uri']}/#{path}"
  end

  def maxElemsPerPage
    config['element_per_page_limit']
  end
end

class Pages  < Struct.new(:uri)
  def scrapedPapers

    uri = "#{Scraper.expand_uri(Scraper.config['recent_papers_path'])}"
    client = HTTPClient.new
    client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    client.receive_timeout=500
    if HTTPClient.respond_to?("client.transparent_gzip_decompression=")
      client.transparent_gzip_decompression = true
    end
    res = client.get uri
    cookie = res.header["Set-Cookie"].first.split(';').first.split('=')

    $i = 0
    $num = Scraper.config['recent_papers_limit']
    papers = Array.new
    
    $showNextStr = "#{Scraper.config['next']}"

    while $i < $num  do
      shownext = ($i > 0) ? $showNextStr : ""
      index = PaperIndex.new("#{uri}#{shownext}", cookie)
      papers.concat index.papers
      $i += Scraper.maxElemsPerPage
    end  

    return papers
  end
end

class Page < Struct.new(:uri, :cookies)
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

    if !cookies.nil?
      cookie = WebAgent::Cookie.new
      cookie.name = cookies.first
      cookie.value = cookies.last
      cookie.url = URI.parse(url)
      client.cookie_manager.add(cookie)
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

class PaperIndex < Page
  def papers
    rows = doc.css('table.tl1 tbody tr')
    rows = rows.take((rows.size < Scraper.maxElemsPerPage) ? rows.size : Scraper.maxElemsPerPage)
    rows.map! do |row|
      parse_row_to_paper(row)
    end
    rows.compact!
    rows
  end

  private

  # extrahiert daten aus einer einzelnen tabellenzeile
  def parse_row_to_paper(row)
    # FIXME: Remove cowardice conditionals
    cells = row.css('td')
    return nil if cells.nil? || cells[1].nil?
    url = Scraper.expand_uri(cells[1].css('a').first['href'])
    published_at = extract_text(cells[4])

    Paper.new(url, attributes: {
      body: Scraper.config['body'],
      published_at: (Date.parse(published_at) unless published_at.empty?),
      paper_type: extract_text(cells[5]),
      originator: extract_text(cells[3]),
    })
  end

  # extrahiert den text aus den tabellenzellen
  def extract_text(cell)
    return nil if cell.nil?
    cell.text
  end
end

class Paper < Page
  def initialize(uri, attributes: {})
    super(uri)
    @predefined_attributes = attributes
  end

  def reference
    doc.css('#risname').first.text.match(/(Vorlage - )(.*)/)[2].squish
  end

  def name
    html = doc.css('.ko1 td:contains("Betreff:") ~ td').first
    html_to_plain_text(html).chomp(' |')
  end

  def body
    # TODO: What's the body here?
    'Halle'
  end

  def content
    extractContent('a[name="allrisSV"]', "Sachverhalt: ")
  end

  def resolution
    extractContent('a[name="allrisBV"]', "Beschlussvorschlag: ")
  end
  
  def extractContent(selector, start)
    shift = 7
    text = ""
    content = doc.css(selector)
    if content.first
      index = content.first.parent.children.index(content.first)
      len = content.first.parent.children.length
      if content.first.parent.children.length >= index+shift
        content = content.first.parent.children[index+shift]
        text = html_to_plain_text(content)
        if text
          text = text.squish
          startIndex = text.index(start)
          if startIndex
            startIndex = startIndex + start.length
            text = text[startIndex..-1]
          end
          puts "text: ", selector, " - ", text
        end
      end
    end
    return text
  end

  def scraped_at
    Time.now
  end

  def published_at
    date = doc.css('#smctablevorgang .smctablehead:contains("Datum") ~ td').text.squish
    Date.parse(date) if date.present?
  end

  def paper_type
    doc.css('#smctablevorgang .smctablehead:contains("Art") ~ td').text.squish
  end

  def originator
  end

  def under_direction_of
  end

  def attributes
    @attributes ||= {
      id: uri,
      url: uri,
      reference: reference,
      name: name,
      body: body,
      content: content,
      resolution: resolution,
      scraped_at: scraped_at,
      published_at: published_at,
      paper_type: paper_type,
      originator: originator,
      under_direction_of: under_direction_of,
    }.merge!(@predefined_attributes)
  end

  private

  def html_to_plain_text(node)
    return unless node
    HtmlToPlainText.plain_text(node.to_s)
  end
end

ScraperWiki.config = { db: 'data.sqlite' }
SQLite3::Database.open 'data.sqlite'

pages = Pages.new(Scraper.expand_uri(Scraper.config['recent_papers_path']))
pages.scrapedPapers.each do |paper|
  paper.attributes
  ScraperWiki.save_sqlite([:id], paper.attributes, 'data')
end