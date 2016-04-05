# -*- coding: utf-8 -*-
require 'optparse'
require 'mechanize'
require 'uri'
require 'json'
require 'log4r'
require 'parallel_runner'

def create_list(keyword, tag)
  data = {
    :keyword => keyword,
    :tag => tag,
    :id => []
  }
  agent = Mechanize.new
  agent.user_agent_alias = 'Mac Mozilla'
  agent.read_timeout = 10
  site = agent.get(URI.encode("https://www.tumblr.com/search/#{tag}"))
  tumblr_lines = (site/'//div[@class="post-info-tumblelog"]/a')
  tumblr_lines.each do |tumblr_line|
    data[:id] << tumblr_line.inner_text
  end
  data
end

def clean(config)
  Net::HTTP.version_1_2
  https = Net::HTTP.new('api.mlab.com', 443)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  https.start do |request|
    raise unless request.put(config['path'] + "?apiKey=#{config['apikey']}", [].to_json, config['header']).code == "200"
  end
end

def save(config, data)
  Net::HTTP.version_1_2
  https = Net::HTTP.new('api.mlab.com', 443)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  https.start do |request|
    raise unless request.post(config['path'] + "?apiKey=#{config['apikey']}", data.to_json, config['header']).code == "200"
  end
end

logger = Log4r::Logger.new("mika4-tumblr-auto-update")
logger.level = 2 # INFO
logger.outputters = []
logger.outputters << Log4r::StdoutOutputter.new('console', {
    :formatter => Log4r::PatternFormatter.new(
      :pattern => "[%l] %d: %M",
      :date_format => "%Y/%m/%d %H:%M:%Sm"
    )
})

file = File.dirname(__FILE__) + "/config/mlab.yml"
config = File.exist?(file) ? YAML.load_file(file) : ENV
config['path'] = '/api/1/databases/%s/collections/%s' % [config['database'], config['collection']]
config['header'] = {'Content-Type' => "application/json"}

clean(config)
logger.info "clean done."

# 声優のあだ名一覧を取得(女性声優のみ)
# ある日構成が変わったり、ページが削除されたら頑張って対応する
agent = Mechanize.new
agent.user_agent_alias = 'Mac Mozilla'
agent.read_timeout = 10
site = agent.get(URI.encode("http://dic.nicovideo.jp/a/声優の愛称一覧"))
list = (site/'//*[@id="article"]/table[2]/tbody/tr/td/ul/li').inject([]) {|l, e| l << e}
list.each_parallel do |line|
  if /(.+)\uFF08(.+)\uFF09/ =~ line.inner_text
    $1.split("\u30FB").each do |nickname|
      save(config, create_list(nickname, $2))
    end
    save(config, create_list($2, $2))
    logger.info "#{$2} done."
  end
end

# カスタムルール(特によく使うもの)
file = File.dirname(__FILE__) + "/config/origin_rules.yml"
origin_rules = YAML.load_file(file)
origin_rules["list"].each_parallel do |keyword|
  save(config, create_list(keyword, keyword))
  logger.info "#{keyword} done."
end
origin_rules["alias"].each_parallel do |tag, keywords|
  keywords.each do |keyword|
    save(config, create_list(keyword, tag))
  end
  logger.info "#{tag} done."
end

logger.info "update done."
