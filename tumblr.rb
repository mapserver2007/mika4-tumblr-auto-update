require 'optparse'
require 'mechanize'
require 'uri'
require 'json'
require 'log4r'
require 'parallel'
require 'digest/md5'

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

def update_name_master(config)
  # 声優のあだ名一覧を取得(女性声優のみ)
  # ある日構成が変わったり、ページが削除されたら頑張って対応する
  master = []
  begin
    agent = Mechanize.new
    agent.user_agent_alias = 'Mac Mozilla'
    agent.read_timeout = 10
    site = agent.get(URI.encode("http://dic.nicovideo.jp/a/声優の愛称一覧"))
    list = (site/'//*[@id="article"]/table[2]/tbody/tr/td/ul/li').inject([]) {|l, e| l << e}
    list.each do |line|
      if /(.+)\uFF08(.+)\uFF09/ =~ line.inner_text
        names = []
        unless $1.index('・').nil?
          names = $1.split('・')
        else
          # ゆいトンは「トン」表記が「ゆい㌧」になっているため補正する
          if $1 == 'ゆい㌧'
            names = [$1, 'ゆいトン']
          else
            names << $1
          end
        end

        origin_name = $2
        origin_names = []
        if origin_name.index('、')
          origin_names = origin_name.split('、')
        else
          # ふーりん(佐本二厘)はふーりん(福原綾香)と被るため除外する
          next if origin_name == '佐本二厘'
          origin_names = [origin_name]
        end

        origin_names.each do |name|
          master << {
            name: name,
            origin_name: name,
            hash: Digest::MD5.hexdigest(name)
          }
          yield :info, name
        end

        names.each do |name|
          origin_names.each do |oname|
            master << {
              name: name,
              origin_name: oname,
              hash: Digest::MD5.hexdigest(oname)
            }
            yield :info, name
          end
        end
      end
    end

    file = File.dirname(__FILE__) + "/config/origin_rules.yml"
    origin_rules = YAML.load_file(file)
    origin_rules["list"].each do |origin_name, keywords|
      keywords.each do |keyword|
        master << {
          name: keyword,
          origin_name: origin_name,
          hash: Digest::MD5.hexdigest(origin_name)
        }
        yield :info, keyword
      end
    end

    clean(config)
    save(config, master)
    yield :info, "rumble_name_master updated."

    master

  rescue => e
    yield :error, e.message
    yield :error, e.backtrace.join("\n")
  end
end

def update_image_master(master, config)
  # 現在の画像マスタデータ
  current_image_master = get(config) || []
  image_master = []

  begin
    search_queries = []
    master.each do |data|
      if data[:name] == data[:origin_name]
        search_queries << {
          url: "https://www.tumblr.com/search/#{data[:name]}/recent",
          name: data[:name],
          hash: data[:hash]
        }
      end
    end

    Parallel.each(search_queries, in_threads: 3) do |query|
      images = search_tumblr(query[:url])
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
  agent = Mechanize.new
  agent.user_agent_alias = 'Mac Mozilla'
  agent.read_timeout = 10
  site = agent.get(URI.encode(url))

  # 最新の画像を取得
  contents = (site/'//section[@class="post_content"]')
  contents.each do |content|
    begin
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
    rescue => e
      yield e.message
    end
  end

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
    JSON.parse(request.get(config['path'] + "?apiKey=#{config['apikey']}").body)
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

file = File.dirname(__FILE__) + "/config/mlab.yml"
mlab = File.exist?(file) ? YAML.load_file(file) : ENV

# 声優マスタデータを作成 洗い替え
config = {}
config['apikey'] = mlab['apikey']
config['path'] = '/api/1/databases/%s/collections/%s' % [mlab['database'], "rumble_name_master"]
config['header'] = {'Content-Type' => "application/json"}
data = update_name_master(config) {|level, message|
  logger.send(level, message)
}

# 画像マスタデータを差分更新
config = {}
config['apikey'] = mlab['apikey']
config['path'] = '/api/1/databases/%s/collections/%s' % [mlab['database'], "rumble_image_master"]
config['header'] = {'Content-Type' => "application/json"}
update_image_master(data, config) {|level, message|
  logger.send(level, message)
}
