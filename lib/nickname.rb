require 'mechanize'
require 'digest/md5'

class NickName
  TYPE_GENERAL = 1
  TYPE_IMAS = 2
  TYPE_UMA = 3


  def agent
    mechanize = Mechanize.new
    mechanize.user_agent_alias = 'Mac Mozilla'
    mechanize.read_timeout = 10
    mechanize
  end

  def sync(type)
    general | umamusume | imas
  end

  def origin

  end

  def general
    # 声優のあだ名一覧を取得(女性声優のみ)
    # ある日構成が変わったり、ページが削除されたら頑張って対応する
    master = []
    url = "http://dic.nicovideo.jp/a/声優の愛称一覧"
    site = agent.get(URI.encode(url))
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
            hash: Digest::MD5.hexdigest(name),
            type: TYPE_GENERAL,
            alias: false
          }
        end

        names.each do |name|
          origin_names.each do |oname|
            master << {
              name: name,
              origin_name: oname,
              hash: Digest::MD5.hexdigest(oname),
              type: TYPE_GENERAL,
              alias: true
            }
          end
        end
      end
    end

    master
  end

  # 以下個別対応

  def umamusume
    master = []
    url = "https://gamewith.jp/umamusume/article/show/96624"
    site = agent.get(URI.encode(url))

    elem = (site/'//div[@class="uma_wrap"]')
    list1, list2 = elem.search("h3"), elem.search("table[@class='pcr_prof']")

    list1.size.times do |i|
      oname = list1[i].text.sub("さん", '')
      master << {
        name: oname,
        origin_name: oname,
        hash: Digest::MD5.hexdigest(oname),
        type: TYPE_UMA,
        alias: false
      }
      nickname = list2[i].search("tr[1]/td[2]").text.sub("【愛称】", '')
      nickname.split(/[,|、]/).each do |name|
        name = name.strip
        master << {
          name: name,
          origin_name: oname,
          hash: Digest::MD5.hexdigest(name),
          type: TYPE_UMA,
          alias: true
        }
      end
    end if list1.size == list2.size

    master
  end

  IMAS_765 = 1
  IMAS_CINDERELLA = 3
  IMAS_MILLION = 4
  def imas
    master = []
    url = "https://imas-db.jp/misc/cv.html"
    site = agent.get(URI.encode(url))

    [IMAS_765, IMAS_CINDERELLA, IMAS_MILLION].each do |i|
      list = (site/"//div[@class='maruamyu-body']/div[#{i}]/table[1]/tbody/tr")
      list.each do |line|
        # 2種類の名前をもつのはM・A・Oだけなので、ruby[1]で1種類に絞る。
        oname = line.search("td[1]/ruby[1]/rb").text
        oname = line.search("td[1]").text if oname == ""

        master << {
          name: oname,
          origin_name: oname,
          hash: Digest::MD5.hexdigest(oname),
          type: TYPE_IMAS,
          alias: false
        }
        line.search("td[2]").text.split(/[,|、]/).each do |name|
          name = name.strip
          next if name == '-'
          master << {
            name: name,
            origin_name: oname,
            hash: Digest::MD5.hexdigest(name),
            type: TYPE_IMAS,
            alias: true
          }
        end
      end
    end

    master
  end
end
