# -*- coding: utf-8 -*-
require 'optparse'
require 'mechanize'
require 'uri'
require 'json'
require 'log4r'
require 'parallel_runner'

def create_list(keyword, tag)
  data = {
    keyword: keyword,
    tag: tag,
    contents: []
  }
  agent = Mechanize.new
  agent.user_agent_alias = 'Mac Mozilla'
  agent.read_timeout = 10
  site = agent.get(URI.encode("https://www.tumblr.com/search/#{tag}/recent"))

  contents = (site/'//section[@class="post_content"]')
  contents.each do |content|
    begin
      text = content.search('div[class="post_body"]/p[1]').text.gsub(/\n/, "")
      content.search('img[class="photo"]').each do |img|
        imgUrl = img.get_attribute("src")
        imgUrl = img.get_attribute("data-src") unless /^https?.+/ =~ imgUrl
        data[:contents] << {img: imgUrl, text: text}
      end
    rescue => e
      yield e.message
    end
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
mlab = File.exist?(file) ? YAML.load_file(file) : ENV
config = {}
config['apikey'] = mlab['apikey']
config['path'] = '/api/1/databases/%s/collections/%s' % [mlab['database'], mlab['collection']]
config['header'] = {'Content-Type' => "application/json"}

clean(config)
logger.info "clean done."

# 声優のあだ名一覧を取得(女性声優のみ)
# ある日構成が変わったり、ページが削除されたら頑張って対応する
begin
  agent = Mechanize.new
  agent.user_agent_alias = 'Mac Mozilla'
  agent.read_timeout = 10
  site = agent.get(URI.encode("http://dic.nicovideo.jp/a/声優の愛称一覧"))
  list = (site/'//*[@id="article"]/table[2]/tbody/tr/td/ul/li').inject([]) {|l, e| l << e}
  list.each do |line|
    if /(.+)\uFF08(.+)\uFF09/ =~ line.inner_text
      $1.split("\u30FB").each do |nickname|
        save(config, create_list(nickname, $2) {|message|
          logger.error message
        })
      end
      save(config, create_list($2, $2))
      logger.info "#{$2} done."
    end
  end

  # カスタムルール(特によく使うもの)
  file = File.dirname(__FILE__) + "/config/origin_rules.yml"
  origin_rules = YAML.load_file(file)
  origin_rules["list"].each do |keyword|
    save(config, create_list(keyword, keyword) {|message|
      logger.error message
    })
    logger.info "#{keyword} done."
  end
  origin_rules["alias"].each do |tag, keywords|
    keywords.each do |keyword|
      save(config, create_list(keyword, tag) {|message|
        logger.error message
      })
    end
    logger.info "#{tag} done."
  end

  logger.info "update success."

rescue => e
  logger.error e.message
  logger.error e.backtrace.join("\n")
  logger.info "update failure."
end
