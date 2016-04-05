# -*- coding: utf-8 -*-
require 'yaml'

task:default => [:github_push, :heroku_deploy]

task :update do
  sh "ruby #{File.dirname(__FILE__)}/tumblr_config.rb"
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
