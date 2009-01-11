#!/usr/local/bin/ruby

require 'date'

class LogEntry
  attr_reader :host, :user, :auth, :date, :referer, :ua, :rcode, :nbytes, :url

  @@epat = Regexp.new('^(\S+) (\S+) (\S+) \[(\d+)\/(\S+)\/(\d+):(\d+):(\d+):(\d+) (.+)\] "(.*)" (\d+) (.*) "(.*)" "(.*)"')
  @@rpat = Regexp.new('^(\S+) (.+) (.+)$')

  def initialize(line)
    md = @@epat.match(line)
    @host = md[1]
    @user = md[2]
    @auth = md[3]
    @day = md[4]
    @month = md[5]
    @year = md[6]
    @hour = md[7]
    @minute = md[8]
    @sec = md[9]
    @diff = md[10]
    @request = md[11]
    @rcode = md[12]
    bs = md[13]
    @nbytes = (bs == "-" ? 0 : Integer(bs))
    @referer = md[14]
    @ua = md[15]

    md = @@rpat.match(@request)
    @method = md[1]
    @url = md[2]
    @proto = md[3]
    @date = @year.to_s() + "-" + Date::ABBR_MONTHNAMES.index(@month).to_s() + "-"+@day.to_s() +" "+@hour.to_s()+":"+@minute.to_s()+":"+@sec.to_s()

  end
  def to_s()
    "LogEntry[host:" + @host + ", date:" + @date + ", referer:" + @referer + ", url:" + @url + ", ua:" + @ua + ", user:" + @user + ", auth:" + @auth + ", rcode:" + @rcode.to_s + ", nbytes:" + @nbytes.to_s + "]";
  end
end
