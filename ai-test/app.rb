require 'sinatra'
require 'resolv'
require 'json'
require 'byebug'
get '/' do
  erb :index
end

post '/lookup' do
  host = params[:host]
  type = params[:type].upcase
  records = Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN.const_get(type))
  begin
    result = records.map do |r|
      puts r.inspect
      puts "TEST"
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
end
