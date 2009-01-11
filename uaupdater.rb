#!/usr/local/bin/ruby

require 'date'
require 'useragents'
require 'rubygems'
require 'active_support'
require 'active_record'


$db = YAML.load_file('db.yaml')
ActiveRecord::Base.establish_connection($db['ksand'])  

class Logs < ActiveRecord::Base
end 

class Sites < ActiveRecord::Base
end

conditions = 'site = "1"'
total =  Logs.count(:all, :conditions => conditions)
puts "Total Lines:"
puts total

group = 0
gsize = 100
i = 1.0

while i <= total
  logs = Logs.find(:all, :conditions => conditions, :limit => "#{group}, #{gsize}")
  break if logs.empty?
  logs.each do |log|
    predone = ((i/total)*100).ceil
    i += 1.0
    ua = UserAgent.new(log.ua)
    Logs.update(log.id, {:platform => ua.platform, :browser => ua.browser, :is_robot => ua.is_robot?, :robot => ua.robot, :requires_human => ua.requires_human})
    perdone = ((i/total)*100).ceil
    print perdone, " Percent Done \n" if (perdone % 5 == 0) && (predone != perdone)
  end
  group += gsize + 1
end

