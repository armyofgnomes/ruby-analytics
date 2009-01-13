#!/usr/local/bin/ruby

require 'rubygems'
require 'date'
require 'time'
require 'yaml'
require 'active_support'
require 'active_record'  
require 'builder'
require 'mechanize'

VISITOR_TIMEOUT = (60 * 30)
IGNORED_IPS = 'ua != "WWW-Mechanize/0.7.2 (http://rubyforge.org/projects/mechanize/)"'

$db = YAML.load_file('db.yaml')
ActiveRecord::Base.establish_connection($db['devsqlite'])

class Logs < ActiveRecord::Base
end 

class Sites < ActiveRecord::Base
end

class Date
  def dim
    d,m,y = mday,month,year
    d += 1 while Date.valid_civil?(y,m,d)
    d - 1
  end
end

puts "Which site?\n"
sitelist = Sites.find(:all)
i = 0
sitelist.each do |site|
  i += 1
	puts "#{i} - #{site[:name]}\n"
end
pick = ($stdin.gets.chomp!.to_i) - 1
siteid = sitelist[pick][:id]
sitename = sitelist[pick][:name]
siteurl = sitelist[pick][:url]
titles = sitelist[pick][:titles_lookup]
limit = sitelist[pick][:limits]
if limit == 0
  limit = 1000000
end

#monthstart = Logs.find(:first, :select => 'logdate', :conditions => "site=#{siteid}", :order => 'logdate ASC')
#monthend = Logs.find(:first, :select => 'logdate', :conditions => "site=#{siteid}", :order => 'logdate DESC')
puts "Which period? \n"
#puts "Select between " + monthstart.logdate.to_s + " and " + monthend.logdate.to_s
puts "Format - (yyyy-mm)"
period = Date::strptime($stdin.gets.chomp! + '-01')
rangestart = period - 1
rangeend = period << -1

#Default conditions for each query
defconds = "site = #{siteid} AND logdate > '#{rangestart.to_s} 23:59:59' AND logdate < '#{rangeend.to_s} 00:00:00' AND host != " + IGNORED_IPS

visitorconds = defconds
logentry = Array.new
logentry = Logs.find(:all, :conditions => visitorconds, :order => 'host, ua, logdate ASC')

counter = 0
repeat = 0
repeatvisitors = Hash.new(0)
timeonsite = Hash.new
avgtos = Array.new
avgtime = 0
i = 0
spiders = Hash.new(0)
browsers = Hash.new(0)
platforms = Hash.new(0)
dailyv = Array.new(period.dim + 1, 0)

logentry.each do |entry|
  timeonsite[entry[:host] + ' - ' + entry[:ua]] = Array.new if timeonsite[entry[:host] + ' - ' + entry[:ua]].class != Array
  timeonsite[entry[:host] + ' - ' + entry[:ua]] << entry[:logdate] unless entry[:logdate].nil?
  if (entry[:host] != logentry[i-1][:host]) || (logentry[i-1][:host].nil?) || (entry[:ua] != logentry[i-1][:ua]) || (entry[:logdate] > logentry[i-1][:logdate] + VISITOR_TIMEOUT)
    counter += 1 #if entry[:rcode] =~ /2\d\d/ && entry[:nbytes] != 0 && entry[:is_robot] == 0
    dailyv[(entry[:logdate].strftime("%d")).to_i] += 1
    #puts "New Host"
    if entry[:is_robot] == 1 || entry [:url] == /robots.txt/ || entry[:requires_human] == 1
      spiders[entry[:robot]] += 1
      #puts entry[:robot]
    else 
      browsers[entry[:browser]] += 1 unless entry[:browser] == "-"
      platforms[entry[:platform]] += 1 unless entry[:platform] == "-"
    end
  end
  if (entry[:host] == logentry[i-1][:host]) && (entry[:ua] == logentry[i-1][:ua]) && (entry[:logdate] > (logentry[i-1][:logdate] + VISITOR_TIMEOUT)) #&& (entry[:is_robot] == 0) && (entry[:requires_human] == 0)
    repeat += 1
    repeatvisitors[entry[:host] + ' - ' + entry[:ua]] += repeat
    #puts "Repeat Visitor"
  end
  preperdone = ((i.to_f/logentry.length) * 100).ceil
  i += 1
  percentdone = ((i.to_f/logentry.length) * 100).ceil
  puts percentdone.to_s + "% Complete \n" if (percentdone % 5 == 0) && (preperdone != percentdone)
end
logentry = nil
puts "Visitors Complete"
puts Time.now

#Time on Site
timeonsite.each do |key, person|
  i = 0
  tis = 0
  if ((person.last - person[0]) < VISITOR_TIMEOUT)
    avgtos << person.last - person[0]
  else 
    person.each do |j|
      if (!person[i+1].nil? && (person[i+1] - person[i]) < VISITOR_TIMEOUT)
        tis += (person[i+1] - person[i])
      else
        avgtos << tis
        tis = 0
      end
      i += 1
    end
  end
end
avgtos.each do |t|
  avgtime += t
end
if (avgtos.length == 0)
  avglength = 1
else
  avglength = avgtos.length
end
avgtime = ((avgtime/avglength)*100).round/100.0
avgtos = nil
timeonsite = nil
puts "Average Time on Site Complete"
puts Time.now

#Pageviews
pageview_conds = defconds + ' AND (' + 'url LIKE "%/" OR url LIKE "%.html" OR url LIKE "%.php%" OR url LIKE "%.htm" OR url LIKE "%.asp%" or url like "%?%")'
pageviews = Logs.count(:all, :conditions => pageview_conds)
puts "Pageviews Complete"
puts Time.now

#Daily Pageviews
dailypv = Array.new
dailypv_conds = " WHERE " + pageview_conds + 'GROUP BY strftime("%d",logdate) ORDER BY strftime("%d",logdate)'
dailypv = Logs.connection.select_all('select strftime("%d",logdate) as day, count(id) as views from logs' + dailypv_conds)  
=begin
day = period
while day < (period + period.dim)
  dailypv_conds = "site = #{siteid} AND logdate > '#{(day - 1).to_s} 23:59:59' AND logdate < '#{(day + 1).to_s} 00:00:00' AND host != " + IGNORED_IPS + ' AND (url LIKE "%/" OR url LIKE "%.html" OR url LIKE "%.php%" OR url LIKE "%.htm" OR url LIKE "%.asp%" or url like "%?%")'
  dailypv << Logs.count(:all, :conditions => dailypv_conds)
  puts day.to_s
  day += 1
end
=end

puts "Daily Pageviews Complete"
puts Time.now

#Unique IPs
unique_ips = Logs.count('host', :distinct => 'true', :conditions => defconds)
puts "Unique IPs Complete"
puts Time.now

#Bookmarks - Inaccurate due to modern browsers always downloading favicons
bookmarks = Logs.count('url', :conditions => defconds + ' AND url LIKE "%favicon.ico"')
puts "Bookmarks Complete"
puts Time.now

#Bandwidth
bytes = Logs.sum('nbytes', :conditions => defconds)
totalbytes = (bytes.to_f/1024/1024).round(2)
puts "Bandwidth Complete"
puts Time.now

#Top Pages
pageconds = 'AND (url LIKE "%.php%" OR url LIKE "%.asp%" OR url LIKE "%.html%" OR url LIKE "%.htm%" OR url LIKE "%.cgi%" OR url LIKE "%/" OR url LIKE "%/?%") AND (rcode like "2%")'
top_pages = Logs.find(:all, :select => 'url, nbytes, COUNT(*) as count', :conditions => defconds + pageconds, :group => 'url', :order => 'COUNT(*) DESC', :limit => limit)
puts "Top Pages Complete"
puts Time.now

#Top Downloaded Files
fileconds = 'AND url LIKE "%.%" AND url NOT LIKE "%.php%" AND url NOT LIKE "%.asp%" AND url NOT LIKE "%.html%" AND url NOT LIKE "%.htm%" AND url NOT LIKE "%.cgi%" AND url NOT LIKE "%/" AND nbytes NOT LIKE "0%"'
fileconds << ' AND url NOT LIKE "%.jpg" AND url NOT LIKE "%.gif" AND url NOT LIKE "%.png" AND url NOT LIKE "%.css" AND url NOT LIKE "%.js"'
top_files = Logs.find(:all, :select => 'url, nbytes, COUNT(*) as count', :conditions => defconds + fileconds, :group => 'url', :order => 'COUNT(*) DESC', :limit => limit)
puts "Top Downloaded Files Complete"
puts Time.now

#Top Search Engines
searchconds = 'AND (referer LIKE "http://%")'
searchengines = Logs.find(:all, :select => 'referer, COUNT(*) as count', :conditions => defconds + searchconds, :group => 'referer', :order => 'COUNT(*) DESC')
puts "Top Search Engines Complete"
puts Time.now

#Top Referers
refererconds = 'AND (referer LIKE "http://%" OR referer LIKE "-")'
referers = Logs.find(:all, :select => 'referer, COUNT(*) as count', :conditions => defconds + refererconds, :group => 'referer', :order => 'COUNT(*) DESC', :limit => limit)
puts "Top Referers Complete"
puts Time.now

#Entry Pages - Exp
entry_pages = Logs.find(:all, :select=> 'host, url, logdate, count(*) as count', :conditions => defconds + pageconds, :group => 'url', :order => 'COUNT(*) DESC', :limit => limit)
puts "Top Entry Pages Complete"
puts Time.now

#Top Errors
errorconds = 'AND (rcode LIKE "4%" OR rcode LIKE "5%")'
errors = Logs.find(:all, :select => 'rcode, url, referer, COUNT(*) as count', :conditions => defconds + errorconds, :group => 'url, referer', :order => 'COUNT(*) DESC', :limit => limit)
puts "Top Errors Complete"
puts Time.now

spidertotal = 0
spiders.sort{ |a,b| b[1] <=> a[1] }.each_with_index do |spider, rank|
  spidertotal += spider[1]
end

browsertotal = 0
browsers.sort{ |a,b| b[1] <=> a[1] }.each_with_index do |browser, rank|
  browsertotal += browser[1]
end

platformtotal = 0
platforms.sort{ |a,b| b[1] <=> a[1] }.each_with_index do |platform, rank|
  platformtotal += platform[1]
end

puts "Begin Building XML"
puts Time.now
#Build the XML
x = Builder::XmlMarkup.new :indent => 2
      x.instruct!
      x.site('name' => sitename, 'period' => period.year.to_s + "-" + period.month.to_s) do
        x.summary do
          x.visitors counter.to_s
          x.views pageviews.to_s
          x.unique_ip unique_ips.to_s
          x.repeat_visitors repeatvisitors.length.to_s
          x.bookmarks bookmarks.to_s
          x.avgtos avgtime.to_s
          x.bandwidth totalbytes.to_s, 'units' => 'MB'
        end
        x.resources do
          x.entry_pages do
          
          end
          x.daily_pageviews do
            dailypv.each do |d|
              x.day(d['day'], 'views'=> d['views'], 'visitors' => dailyv[d['day'].to_i])
            end
          end
          x.top_requested_pages do
            i = 1
            top_pages.each do |pageitem|
              pagename = pageitem[:url]
              if titles
                agent = WWW::Mechanize.new
                puts 'http://' + siteurl + pageitem[:url]
                begin
                  webpage = agent.get('http://' + siteurl + pageitem[:url])
                  pagename = webpage.title.strip if defined?(webpage.title.strip) && defined?(webpage) && !webpage.title.strip.nil? && webpage.title.strip != '' && webpage.title != "OpenDNS"
                rescue
                  pagename = pageitem[:url]
                end
              end
              i += 1
            end
          end
          x.top_files do
            i = 1
            top_files.each do |download|
              x.file(download[:url], 'rank' => i, 'count' => download[:count], 'size' => download[:nbytes])
              i += 1
            end
          end
        end
        x.referers do
          i = 1
          domains = Hash.new(0)
          referers.each do |referer|
            if referer[:referer] =~ /-/
              domains['-'] += 1 + referer[:count].to_i
            end
            referer[:referer].scan(/^http:\/\/w{3}*\.*([\w|\-+\.\w|\-+]*)/){ |domain|
                domains[domain] += 1 + referer[:count].to_i
            }
          end
          domains.sort{ |a,b| b[1] <=> a[1] }.each do |domain, count|
            x.referer(domain, 'rank' => i, 'count' => count)
          end
          i += 1
        end
        x.entry_pages do
          i = 1
          entry_pages.each do |page|
            x.page(page[:url], 'rank' => i, 'count' => page[:count])
            i += 1
          end
        end
        x.search_engines do
          engines = Hash.new
          allphrases = Hash.new(0)
          allterms = Hash.new(0)
          enginelist = ['google', 'yahoo', 'live', 'msn', 'ask', 'aol', 'baidu']
          searchengines.each do |engine|
              enginelist.each do |item|
                  if engine[:referer] =~ /#{item}/
                    if engines[item].nil? then engines[item] = Hash.new end
                    engine[:referer].scan(/[&\?](q|p|searchfor|as_q|as_epq|s|query)=([^&]+)/i){ |phrase|
                      phrase = phrase[1].to_s.downcase
                      if engines[item][:count].nil? then engines[item][:count] = 0 end
                      engines[item][:count] += 1
                      if engines[item][:phrases].nil? then engines[item][:phrases] = Hash.new(0) end
                      if engines[item][:phrases][phrase].nil? then engines[item][:phrases][phrase] = 0 end
                      engines[item][:phrases][phrase] += 1
                      allphrases[phrase] += 1
                      phrase.split("+").each do |term|
                        term.downcase!
                        if engines[item][:terms].nil? then engines[item][:terms] = Hash.new(0) end
                        if engines[item][:terms][term].nil? then engines[item][:terms][term] = 0 end
                        engines[item][:terms][term] += 1
                        allterms[term] += 1
                      end
                    }
                  end
              end
           end
           x.summary do 
             i = 0
             allphrases.sort{ |a,b| b[1] <=> a[1]}.each do |phrase, count|
               i += 1
               x.phrase(phrase, 'count' => count, 'rank' => i)
             end
             i = 0
             allterms.sort{ |a,b| b[1] <=> a[1]}.each do |term, count|
               i += 1
               x.term(term, 'count' => count, 'rank' => i)
             end 
           end
          engines.each do |engine, items|
            unless items[:phrases].nil? ||  items[:terms].nil?
              x.engine('engine' => engine.capitalize, 'count' => items[:count]) do
                x.phrases do 
                  i = 0
                  items[:phrases].sort{ |a,b| b[1] <=> a[1] }.each do |phrase, count|
                    i += 1
                    x.phrase(phrase, 'count' => count, 'rank' => i)
                  end
                end
                x.terms do
                  i = 0
                  items[:terms].sort{ |a,b| b[1] <=> a[1] }.each do |term, count|
                    i += 1
                    x.term(term, 'count' => count, 'rank' => i)
                  end
                end
              end
            end
          end
        end
        x.clients do
          x.browsers do
            i = 1
            browsers.sort{ |a,b| b[1] <=> a[1] }.each_with_index do |browser, rank|
              x.browser(browser[0].to_s, 'rank' => (rank+1), 'count' => browser[1], 'percentage' => (browser[1].to_f/browsertotal).round(4)*100)
              i += 1
            end
          end
          x.platforms do 
            i = 1
            platforms.sort{ |a,b| b[1] <=> a[1] }.each_with_index do |platform, rank|
              x.platform(platform[0].to_s, 'rank' => (rank+1), 'count' => platform[1], 'percentage' => (platform[1].to_f/platformtotal).round(4)*100)
              i += 1
            end
          end
        end
        x.errors do
          i = 1
          errors.each do |error|
            x.error(error[:url], 'rank' =>i, 'count' => error[:count], 'rcode' => error[:rcode], 'referer' => error[:referer])
            i += 1
          end
        end
      end
      
      xml ||= x
      xml = xml.to_s.gsub('<to_s/>', '')
      #puts xml
      
      f = File.open('xml/' + sitename + period.year.to_s + "-" + period.month.to_s + ".xml", "w")
      f.puts xml
      f.close
puts "XML Build Complete"
puts Time.now
exit
