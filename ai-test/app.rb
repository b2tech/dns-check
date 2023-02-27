require 'sinatra'
require 'resolv'
require 'json'
require 'byebug'
require 'net/http'
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

  uri = URI::HTTP.build(host: host)
  response = Net::HTTP.get_response(uri)
  all_records["HTTP Response code"] = response.code
 
  uri = URI::HTTP.build(host: host, scheme: "https")
  response = Net::HTTP.get_response(uri)
  all_records["HTTPS Response code"] = response.code

  all_records["Your IP"] = request.env["REMOTE_ADDR"]
byebug
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
