#!/usr/local/bin/ruby
require 'yaml'

class UserAgent
  $config = YAML.load_file('useragents.yaml')
  @@platforms = $config['Platforms']
  @@browsers = $config['Browsers']
  @@mobiles = $config['Mobiles']
  @@robots = $config['Robots']
  
      #UA String - Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.11) Gecko/20071127 Firefox/2.0.0.11 
	def initialize(user_agent_string)
        @uastring = user_agent_string.gsub(/\+/, " ")
        self.platform?()
        self.browser?()
        self.robot?()
        self.is_robot?()
        self.requires_human?()
	end 
	def platform?()
  		@@platforms.each_key do |plat|   
            if /#{plat}/i =~ @uastring 
              @plat = @@platforms[plat]
            end
        end
        if @plat.nil?
        	return "-"
        else
        	return @plat	
        end
	end
	def browser?()
	  	@@browsers.each do |nick|
	        if /#{nick.keys}/i =~ @uastring
	          @brow = nick.values.to_s
	          unless Regexp.new("#{nick.keys}.([0-9]*\.[0-9]*)(;|,|.)").match(@uastring).nil?
	           @brwver = Regexp.new("#{nick.keys}.([0-9]*\.[0-9]*)(;|,|.)").match(@uastring)[1]
	          end
	          if @brwver.nil?
	          	@brwver = ' '
	          end
	          break
	        end
	 	end
	 	if @brow.nil?
	 		return "-"
	 	else
	 		return @brow + " " + @brwver
	 	end
	end
  def requires_human?()
    if @bot.nil? && @brow.nil? && @plat.nil?
      return 1
    else
      return 0
    end
  end 
	def is_robot?()
		if @bot.nil?
      return 0
    else
    	return 1
    end
	end    
	def robot?()
  		@@robots.each_key do |bot|
        	if /#{bot}/i =~ @uastring 
              @bot = @@robots[bot]
              begin
              @botlink = Regexp.new('^.*(http://.*)\)') .match(@uastring)[1]
              rescue
              @botlink = "No link available"
              end
            end
        end
        if @bot.nil?
        	return "-"
        else
        	return @bot + " " + @botlink
        end   
    end
	def to_s()
    if @plat.nil? && @brow.nil? && @bot.nil?
      @uastring
    end
    if @plat.nil?
      @plat = "Unknown"
    end
    if @brow.nil?
      @brow = "Unknown"
      @brwver = ""
    end
    if @bot.nil? || @bot.chomp == ""
    	if @plat == "-" && @brow == "-"
    	"UA String: " + @uastring
    	else
    	"Platform: " + @plat + ", Browser: " + @brow + " " + @brwver 
    	end
    else
    "Crawler: " + @bot + " - " + @botlink
    end
	end 
end
