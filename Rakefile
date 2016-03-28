# -*- coding: utf-8 -*-
require 'yaml'

task:default => [:github_push, :heroku_deploy]

task :update_config => [:clean, :insert]

task :clean do
  sh "heroku run ruby #{File.dirname(__FILE__)}/tumblr_config.rb -d"
end

task :insert do
  keyword = "ごらく部"
  tag = "七森中☆ごらく部,三上枝織,大坪由佳,津田美波,大久保瑠美"
  sh "heroku run ruby #{File.dirname(__FILE__)}/tumblr_config.rb -w #{keyword} -t #{tag}"

  keyword = "ゆるゆり"
  tag = "ゆるゆり,なもり,赤座あかり,歳納京子,船見結衣,吉川ちなつ"
  sh "heroku run ruby #{File.dirname(__FILE__)}/tumblr_config.rb -w #{keyword} -t #{tag}"

  keyword = "ラブライブ"
  tag = "ラブライブ！,ラブライブ,高坂穂乃果"
  sh "heroku run ruby #{File.dirname(__FILE__)}/tumblr_config.rb -w #{keyword} -t #{tag}"
end

task :github_push do
  sh 'git push origin master'
end

task :heroku_deploy => [:github_push] do
  sh 'git push heroku master'
end

task :heroku_env => [:heroku_env_clean, :timezone, :lang] do
  config_files = [
    YAML.load_file(File.dirname(__FILE__) + "/config/mlab.yml")
  ]
  config = {}
  config_files.each do |file|
    file.each {|key, value| config[key] = value}
  end

  config.each do |key, value|
    sh "heroku config:add #{key}=#{value}"
  end
end

task :heroku_env_clean do
  config.each do |key, value|
    sh "heroku config:remove #{key}"
  end
end

task :timezone do
  sh "heroku config:add TZ=Asia/Tokyo"
end

task :lang do
  sh "heroku config:set LANG=ja_JP.UTF-8"
end

task :heroku_start do
  sh "heroku scale clock=1"
end

task :heroku_stop do
  sh "heroku scale clock=0"
end
