# -*- coding: utf-8 -*-
require 'yaml'

task:default => [:github_push, :heroku_deploy]

task :update => [:clean, :insert]

task :clean do
  sh "ruby #{File.dirname(__FILE__)}/tumblr_config.rb -d"
end

def execute_command(keyword, tag)
  sh "ruby #{File.dirname(__FILE__)}/tumblr_config.rb -w #{keyword} -t #{tag}"
end

task :insert do
  execute_command "ごらく部", "七森中☆ごらく部,三上枝織,大坪由佳,津田美波,大久保瑠美"
  execute_command "みかしー", "三上枝織,mikami shiori"
  execute_command "るみるみ", "大久保瑠美,ookubo rumi"
  execute_command "ゆかちん", "大坪由佳,ootsubo yuka"
  execute_command "つだちゃん", "津田美波,tsuda minami"
  execute_command "ゆるゆり", "ゆるゆり,なもり,赤座あかり,歳納京子,船見結衣,吉川ちなつ"
  execute_command "ラブライブ", "ラブライブ！,ラブライブ,高坂穂乃果,南ことり,園田海未,西木野真姫,星空凛,小泉花陽,絢瀬絵里,東條希,矢澤にこ"
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
  config_files = [
    YAML.load_file(File.dirname(__FILE__) + "/config/mlab.yml")
  ]
  config = {}
  config_files.each do |file|
    file.each {|key, value| config[key] = value}
  end

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
