# -*- coding: utf-8 -*-
require 'optparse'
require 'mechanize'
require 'uri'
require 'json'

# Usage
# tumblr_config.rb -d
# tumblr_config.rb --w ごらく部 --t 七森中☆ごらく部,三上枝織

config = {}
is_delete = false
OptionParser.new do |opt|
  opt.on('-d', '--delete') {|boolean| is_delete = boolean}
  opt.on('-w', '--keyword KEYWORD') {|v| config[:keyword] = v.force_encoding("UTF-8")}
  opt.on('-t', '--tag TAG', Array) {|v| config[:tag] = v}
  opt.parse!
end

file = File.dirname(__FILE__) + "/config/mlab.yml"
mlab = File.exist?(file) ? YAML.load_file(file) : ENV
database = mlab['database']
collection = mlab['collection']
apiKey = mlab['apikey']
path = '/api/1/databases/%s/collections/%s' % [database, collection]
header = {'Content-Type' => "application/json"}

if is_delete
  Net::HTTP.version_1_2
  https = Net::HTTP.new('api.mlab.com', 443)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  https.start do |request|
    raise unless request.put(path + "?apiKey=#{apiKey}", [].to_json, header).code == "200"
  end
  puts "clean done."

  exit
end

blog_id_list = []
agent = Mechanize.new
agent.user_agent_alias = 'Mac Mozilla'
agent.read_timeout = 10

config[:tag].each do |tag|
  tag.force_encoding("UTF-8")
  site = agent.get(URI.encode("https://www.tumblr.com/search/#{tag}"))
  lines = (site/'//div[@class="post-info-tumblelog"]/a')
  lines.each do |line|
    blog_id_list << line.inner_text
  end
end
config[:id] = blog_id_list

Net::HTTP.version_1_2
https = Net::HTTP.new('api.mlab.com', 443)
https.use_ssl = true
https.verify_mode = OpenSSL::SSL::VERIFY_NONE
https.start do |request|
  raise unless request.post(path + "?apiKey=#{apiKey}", config.to_json, header).code == "200"
end

puts "update done."
