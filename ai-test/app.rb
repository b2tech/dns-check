require 'sinatra'
require 'resolv'
require 'json'
require 'byebug'
require 'net/http'
require 'whois'
require 'mechanize'
require 'nokogiri'
require 'openssl'
require 'benchmark'

get '/' do
  erb :index
end

post '/lookup' do
  host = params[:host]
  types = ["NS", "A", "AAAA", "CNAME", "MX", "TXT"]
  all_records = {}
  types.each do |t|
    records = Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN.const_get(t))
    record_data = ""
    begin
      result = records.map do |r|
        case t 
        when "CNAME"
          record_data = r.name.to_s
        when "A", "AAAA" 
          record_data = r.address.to_s
        when "NS"
          record_data = r.name.to_s
        when "MX"
          record_data = "#{r.preference} #{r.exchange.to_s}"
        when "TXT"
          record_data = r.data.to_s
        else
          record_data = r.data.to_s
        end
      end
      all_records[t] = record_data     
    rescue Resolv::ResolvError => e
      content_type :json
      { status: 'error', message: e.message }.to_json
    end
  end
  response = ""
  #http response
  uri = URI::HTTP.build(host: host)
  http_page_load_speed = Benchmark.realtime do
    response = Net::HTTP.get_response(uri)
    response.body
    all_records["HTTP Response code"] = response.code
  end

  #https response
  uri = URI::HTTP.build(host: host, scheme: "https")
  
  https_page_load_speed = Benchmark.realtime do
    response = Net::HTTP.get_response(uri)
    response.body
  end
  all_records["http load speed"] = "#{http_page_load_speed.round(2)} seconds"
  all_records["https load speed"] = "#{https_page_load_speed.round(2)} seconds"

  all_records["HTTPS Response code"] = response.code

  #remote ip
  all_records["Your IP"] = request.env["REMOTE_ADDR"]

  #whois 
  c = Whois::Client.new
  whois = c.lookup(host)
  all_records["WHOIS"] = whois

  # ssl
  socket = TCPSocket.new(host, 443)
  ssl_context = OpenSSL::SSL::SSLContext.new
  ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
  ssl_socket.hostname = host
  ssl_socket.connect
  cert = ssl_socket.peer_cert

  all_records["SSL Info"] = ""
  all_records["Certificate subject"] = cert.subject
  all_records["Certificate issuer"] = cert.issuer
  all_records["Certificate serial number"] = cert.serial
  all_records["Certificate not before"] = cert.not_before
  all_records["Certificate not after"] = cert.not_after
  all_records["Certificate subject alternative names"] = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }.value



  #baclinks
  agent = Mechanize.new
  page = agent.get(uri)

#  if page.is_a?(Mechanize::Page) && page.meta_refresh
#    page = page.follow_meta_refresh
#  end
  
  if page.is_a?(Mechanize::Page) && page.code.to_i / 100 == 3
    page = page.follow_redirect
  end
  html = Nokogiri::HTML(page.body)
  server_info_response = page.header
  # Server info

  all_records["SERVER INFO"] = ""
  server_info_response.each do |k, v|
    all_records[k] = v
  end
=begin
  all_records["Server date"] = server_info_response["date"]
  all_records["Server"] = server_info_response["Server"]
  all_records["Vary"] = server_info_response["vary"]
  all_records["expires"] = server_info_response["expires"]
  all_records["cache-control"] = server_info_response["cache-control"]
  all_records["pragma"] = server_info_response["pragma"]
  all_records["link"] = server_info_response["link"]
  all_records["set-cookie"] = server_info_response["set-cookie"]
  all_records["upgrade"] = server_info_response["upgrade"]
  all_records["connection"] = server_info_response["connection"]
  all_records["content-encoding"] = server_info_response["content-encoding"]
  all_records["keep-alive"] = server_info_response["keep-alive"]
  all_records["transfer-encoding"] = server_info_response["transfer-encoding"]
  all_records["content-type"] = server_info_response["content-type"]
  all_records["X-Powered-By"] = server_info_response["X-Powered-By"]
  all_records["inspect"] = server_info_response.inspect
=end
  links = html.css('a')

  header_tag_content = {} 

  header_tags = ["h1", "h2", "h3", "h4", "h5", "h6"]
  header_tags.each do |h|
    header_tag_content[h] = []
    html.css(h).each do |hdr|
      header_tag_content[h] << hdr.text
    end
  end

 

  backlinks = []
  backlink_text = []

  external_links = []
  external_link_text = []

  links.each do |link|
    href = link["href"]
    if !href.include?(host) && href.include?("://")

      external_link_text << link.text 
      external_links << href 
    else
      backlink_text << link.text
      backlinks << href 
    end
  end

  all_records["TITLE"] = page.css('title').text

  # meta
  all_records["META INFO"] = ""
  page.css('meta').each do |m|
    k = m["name"]
    all_records[k] = m["content"]
  end
  all_records["BACKLINKS"] = ""
  backlinks.each_with_index do |b, i|
    all_records[b] = backlink_text[i]
  end
  all_records["EXTERNAL LINKS"] = ""
  external_links.each_with_index do |e, i|
    all_records[e] = external_link_text[i] 
  end
  
  all_records["HEADER TAGS"] = ""
  header_tag_content.each do |k, v|
    all_records["#{k}"] = ""

    c = 1
    kn = "#{c} - #{k}"
    v.each do |htag|
      kn = "#{c} - #{k}"
      all_records[kn] = v
      c = c + 1
    end
  end

  all_records["PARAGRAPHS"] = ""
  pz = []
  page.css('p').each do |p|
    pz << p.text
  end
  c = 1
  pz.each do |p|
    k = "#{c} - p"
    all_records[k] = p
    c = c + 1
  end

  content_type :json
  { status: 'success', result: all_records }.to_json
=begin
#  type = params[:type].upcase

  records = Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN.const_get(type))
  begin
    result = records.map do |r|
      case type 
      when "CNAME"
        r.name.to_s
      when "A", "AAAA" 
        r.address.to_s
      when "NS"
        r.name.to_s
      when "MX"
        "#{r.preference} #{r.exchange.to_s}"
      when "TXT"
        r.data.to_s
      else
        r.data.to_s
      end
    end
   
    content_type :json
    { status: 'success', result: result }.to_json
  rescue Resolv::ResolvError => e
    content_type :json
    { status: 'error', message: e.message }.to_json
  end
=end
end
