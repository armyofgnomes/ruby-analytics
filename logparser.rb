#!/usr/local/bin/ruby

require 'date'
require 'logentry'
require 'useragents'
require 'rubygems'  
require 'active_support'
require 'active_record'
require 'net/ftp'
require 'digest'


$db = YAML.load_file('db.yaml')
ActiveRecord::Base.establish_connection($db['devsqlite'])  

class Logs < ActiveRecord::Base
end 

class Sites < ActiveRecord::Base
end

nlines = 0
tlines = 0
ftpit = 0
isdir = 0
if ARGV.length < 1
  ftpit = 1
end

#puts "Usage:: [ruby] logparser.rb <inpfile>" if ARGV.length < 1
if ftpit == 1
  puts "You haven't chosen a log file to parse, ftp connection will be attempted. Is that okay?"
  exit if $stdin.gets.downcase.chomp! == ('n' || 'no')
elsif File.directory?(ARGV[0])
  isdir = 1
  dir = ARGV[0]
else
  filename = ARGV[0]
end

if isdir == 1
  logs = Array.new()
  Dir.foreach(dir) {|d| 
    if d != '.' && d != '..' && d =~ /\.gz$/
      puts "Log #{d}"
      logs.push(d)
      #puts addy.scan(/w+\.([\w|-]+)\./).to_s
      puts d.scan(/([\w|-]+)[\.w{3}]*\.[\w|-]+\.[\w|-]+/).to_s
    end 
  }
  p logs
  logs.each do |log|
    logname = log.scan(/([\w|-]+[\.w{3}]*\.)(com|org|net)[\w|-]+\.[\w|-]+/).to_s
    puts logname
    site = Sites.find(:first, :conditions => 'url = "www.' + logname + '"')
  end
  exit
end

puts "Which site?\n"
sitelist = Sites.find(:all)
sitelist.each do |site|
	puts "#{site[:id]} - #{site[:name]}\n"
end
puts "n - New Site\n"

id = $stdin.gets.chomp!
#print "Site Id: ", id

if id == "n"
	puts "What is the name of the site?\n"
	newsite = $stdin.gets.chomp!
	puts "What is the web address of the site? (www.example.com - no trailing slash or leading http)"
	address = $stdin.gets.chomp!
	puts "FTP Username?"
	username = $stdin.gets.chomp!
	puts "FTP Password?"
	password = $stdin.gets.chomp!
	#Add new site to sites table
	Sites.create(:name => newsite, :url => address, :username => username, :password => password, :timestamp => Time.now.strftime("%Y-%m-%d %H:%M:%S"))
	site = Sites.find(:first, :conditions => [ "name = ?", newsite])
else
  site = Sites.find(:first, :conditions => "id = #{id}")
end
  id = site[:id]

if ftpit == 1
  addy = site[:url].scan(/[w{3}]*\.([\w|-]+\.[\w|-]+)/).to_s
  user = site[:username]
  pass = site[:password]
  site = site[:name]
  Net::FTP.open(addy, user, pass) do |ftp|
    #files = ftp.chdir('logs') Ideally, make an ftp account just for the logs folder so user/pass can't be compromised
    puts "What log are we retrieving? (1, 2, etc.)\n"
    i = 1
    logs = Array.new
    files = ftp.list(addy + '*') do |log|
      logs[i-1] = log.scan(/(#{addy}-\w{3}-\d{4}\.gz)/).to_s
      p logs
      puts i.to_s + " - " + log.scan(/#{addy}-(\w{3}-\d{4})/).to_s
      i += 1
    end
    choice = $stdin.gets.chomp!.to_i - 1
    @file = logs[choice].to_s
    ftp.getbinaryfile(@file, "logs/#{@file}", 1024)
  end
  filename = "logs/#{@file}"
end
if filename =~ /\.gz$/
  #Have to decompress the thing, for some reason GzipReader doesn't handle appended gz files, so we must recompress concatenated files or just unzip the thing
  IO.popen("gunzip -d #{filename}", "r")
  Process.wait
  filename = 'logs/' + filename.scan(/([\w|\-|\.]+).gz/).to_s
  #inpfile = Zlib::GzipReader.open(filename)
  #Counting total lines
  #Zlib::GzipReader.open(filename) { |line|
  #    tlines += 1 while line.gets
  #}
end

inpfile = File.open(filename)
#Counting total lines
File.open(filename, 'r') { |line|
    tlines += 1 while line.gets
}
while line = inpfile.gets
  preperdone = ((nlines.to_f/tlines)*100).ceil
  nlines += 1
  begin
    le = LogEntry.new(line)
    ua = UserAgent.new(le.ua)
    line_sha1 = Digest::SHA1.hexdigest(le.host.to_s + le.date.to_s + le.referer.to_s + le.referer.to_s + le.url.to_s + le.ua.to_s + le.user.to_s + le.auth.to_s + le.rcode.to_s + le.nbytes.to_s + id.to_s)
    Logs.create({:sha1 => line_sha1, :host => le.host, :logdate => le.date, :referer => le.referer, :url => le.url, :ua => le.ua, :user => le.user, :auth => le.auth, :rcode => le.rcode, :nbytes => le.nbytes, :site => id, :platform => ua.platform?, :browser => ua.browser?, :is_robot => ua.is_robot?, :robot => ua.robot?, :requires_human => ua.requires_human?, :timestamp => Time.now.strftime("%Y-%m-%d %H:%M:%S")})
    #print le, "\n"
    percentdone = ((nlines.to_f/tlines)*100).ceil
    print percentdone, " Percent Done \n" if (percentdone % 5 == 0) && (preperdone != percentdone)
  rescue
    #print "Log entry parse failed at line: ", (nlines), ", error: ", $!, "\n"
    #print "LINE: ", line, "\n"
    f = File.open(filename + 'errors' + Time.now.strftime("%Y-02") + ".txt", "a")
    f.print "Log entry parse failed at line: ", (nlines), ", error: ", $!, "\n"
    f.print "LINE: ", line, "\n"
    f.close
  end
end
#Zip the file back up
file = IO.popen("gzip #{filename}", "r")
