# -*- coding: utf-8 -*-
$: << File.dirname(__FILE__) + "/../lib"
require 'nickname'
require 'mechanize'
require 'uri'
require 'log4r'
require 'parallel'
require 'yaml'
require 'json'
require 'openssl'
require 'net/https'

def agent
  mechanize = Mechanize.new
  mechanize.user_agent_alias = ['Mac Mozilla', 'Mac Safari', 'iPhone', 'Windows Mozilla'].sample
  mechanize.read_timeout = 10
  mechanize
end

def create_list(keyword, tag)
  data = {
    keyword: keyword,
    tag: tag,
    contents: []
  }
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

def update_image_master(master, config)
  # 現在の画像マスタデータ
  current_image_master = get(config) || []
  image_master = []

  begin
    search_queries = []
    master.each do |data|
      # TODO あだ名の場合はhashを正式名のものにおきかえ


      if data['name'] == data['origin_name']
        search_queries << {
          url: "https://www.tumblr.com/search/#{data['name']}/recent",
          name: data['name'],
          hash: data['hash']
        }
      end
    end

    Parallel.each(search_queries, in_threads: 3) do |query|
      images = search_tumblr(query[:url]) do |msg|
        yield :error, msg
      end

      if current_image_master.empty?
        image_master << {
          id: query[:hash],
          images: images
        }
        yield :info, "#{query[:name]}: #{images.size} images inserted."
      else
        tmp_image_master = []
        current_image_master.each do |current_image_master_elem|
          if current_image_master_elem['id'] == query[:hash]
            images.delete_if {|image|
              current_image_master_elem['images'].find {|current_image_master_elem_image|
                image[:url] == current_image_master_elem_image['url']
              }.nil? == false
            }

            yield :info, "#{query[:name]}: #{images.size} images updated."

            tmp_image_master << {
              id: query[:hash],
              images: current_image_master_elem['images'].concat(images)
            }

            break
          end
        end

        if tmp_image_master.empty?
          image_master << {
            id: query[:hash],
            images: images
          }
          yield :info, "#{query[:name]}: #{images.size} images inserted."
        else
          image_master.concat(tmp_image_master)
        end
      end
    end

    clean(config)
    save(config, image_master)

  rescue => e
    yield :error, e.message
    yield :error, e.backtrace.join("\n")
  end
end

def search_tumblr(url)
  images = []

  begin
    site = agent.get(URI.encode(url))
    contents = (site/'//section[@class="post_content"]')
    contents.each do |content|
      text = content.search('div[class="post_body"]/p[1]').text.gsub(/\n/, "")
      updated_at = Time.now
      content.search('img[class="photo"]').each do |img|
        url = img.get_attribute("src")
        url = img.get_attribute("data-src") unless /^https?.+/ =~ url
        images << {
          url: url,
          text: text,
          priority: 10,
          updated_at: updated_at
        }
      end
    end
  rescue => e
    yield e.message
  end

  # 最新の画像を取得
  images
end

def https_start
  Net::HTTP.version_1_2
  https = Net::HTTP.new('api.mlab.com', 443)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  https.start { yield https }
end

def clean(config)
  https_start do |request|
    raise unless request.put(config['path'] + "?apiKey=#{config['apikey']}", [].to_json, config['header']).code == "200"
  end
end

def get(config)
  https_start do |request|
    param = config['param'].collect {|k, v| "#{k}=#{v}"}.join("&")
    JSON.parse(request.get(config['path'] + "?#{param}").body)
  end
end

def save(config, data)
  https_start do |request|
    raise unless request.post(config['path'] + "?apiKey=#{config['apikey']}", data.to_json, config['header']).code == "200"
  end
end

logger = Log4r::Logger.new("rumble-crawler")
logger.level = 2 # INFO
logger.outputters = []
logger.outputters << Log4r::StdoutOutputter.new('console', {
  formatter: Log4r::PatternFormatter.new(
    pattern: "[%l] %d: %M",
    date_format: "%Y/%m/%d %H:%M:%Sm"
  )
})

file = File.dirname(__FILE__) + "/../config/mlab.yml"
mlab = File.exist?(file) ? YAML.load_file(file) : ENV

# 日付からtype選択
type_num = 3
type = Time.now.day % type_num + 1

# 声優マスタデータを作成 洗い替え
config = {}
config['param'] = { apiKey: mlab['apikey'], q: {type: type}.to_json }
config['apikey'] = mlab['apikey']
config['path'] = '/api/1/databases/%s/collections/%s' % [mlab['database'], "rumble_name_master"]
config['header'] = {'Content-Type' => "application/json"}
nickname = NickName.new

list = nickname.sync(type)

list.each do |elem|
  logger.info elem.to_s
end

clean(config)
save(config, list)
logger.info "done."

master_data = get(config)

# 画像マスタデータを差分更新
config = {}
config['param'] = { apiKey: mlab['apikey'] }
config['apikey'] = mlab['apikey']
config['path'] = '/api/1/databases/%s/collections/%s' % [mlab['database'], "rumble_image_master"]
config['header'] = {'Content-Type' => "application/json"}
update_image_master(master_data, config) {|level, message|
  logger.send(level, message)
}
