#############################################################################
#
# This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################

# Mechanize tests with Orkut/Twitter
# @author Davis Zanetti Cabral
# @author Leonardo Alexandre Ferreira Leite (leonardofl87@gmail.com)
# Davis original: http://gist.github.com/104221

# Orkut usage example:
# >> require 'jum_proxy'
# >> orkut = JumProxy::Sites::Orkut.new("daviscabral@gmail.com", "pa$$w0rd", "pt-BR")
# >> orkut.scraps	# list of OrkutUser objects
# >> orkut.friends	# list of Scrap objects
#
# Twitter usage example:
# >> require 'jum_proxy'
# >> twitter = JumProxy::Sites::Twitter.new("daviscabral", "pa$$w0rd")
# >> twitter.tweets
# >> twitter.tweets("anyuser")
# >> twitter.post("Reading a book? :-)")

require 'rubygems' # apt-get install libwww-mechanize-ruby1.8 
require 'mechanize'
require 'nokogiri'
require 'uri'

module JumProxy
  class NotFound < StandardError; end
  class NotLoggedIn < StandardError; end
  class NotAuthorized < StandardError; end
  class ArgumentInvalid < StandardError; end
  
  class Base
    attr_accessor :agent, :user_input, :pass_input, :logged_in
    def get(url)
      raise JumProxy::ArgumentInvalid, "URL can't be blank" if url.nil? || url.empty?
      self.agent = WWW::Mechanize.new if self.agent.nil?        
      self.agent.get(url)

      unless self.agent.page
        raise JumProxy::NotFound, "JumProxy can’t open the page “#{url}”."
      else
        self.agent.page
      end
    end
    
    def login(user, pass, url)
      page = self.get(url)
      form = page.forms.first
      
      # Fill/submit form
      form[self.user_input] = user
      form[self.pass_input] = pass        
      self.agent.submit(form)
    end
    
    def logged_in?
      self.logged_in == true
    end
  end  
  
  module Sites    
    class Orkut < JumProxy::Base
      def initialize(user, pass, lang='en-US')
        self.user_input = "Email"
        self.pass_input = "Passwd"
        url = "https://www.google.com/accounts/ServiceLogin?service=orkut&hl=#{lang}"+
              "&rm=false&continue=http%3A%2F%2Fm.orkut.com%2FRedirLogin%3Fmsg%3D0%26"+
              "page%3Dhttp%253A%252F%252Fm.orkut.com%252FHome&cd=US&nui=5&btmpl=mobi"+
              "le&ltmpl=mobile&passive=true&skipvpage=true&sendvemail=false"
        page = self.login(user, pass, url)
        
        unless page.body.match("errormsg_0_Passwd").nil?
          raise JumProxy::NotAuthorized, "JumProxy can't login with this credential (#{user})."
        else        
          page = self.agent.get page.meta.first.attributes['href'].gsub(/'/,'')
          page = self.agent.get page.uri.to_s.sub(/\?.*$/, "?ui=html&zy=n")
          self.logged_in = true
        end
      end
      
      def scraps(user=nil) 
        raise JumProxy::NotLoggedIn, "You need login before access this resource." unless logged_in?
        if user.nil?
          page = self.get("http://m.orkut.com:80/Scrapbook")
        elsif user.respond_to?("uid") #OrkutUser parameter
          page = self.get("http://m.orkut.com/Scrapbook?uid=" + user.uid)
	else # hope user it's a uid string
          page = self.get("http://m.orkut.com/Scrapbook?uid=" + user)
        end
        scrap_items = [] # it's a list of Nokogiri::XML::Element objects
        page.parser.css("div.mblock").each do |block|
            scrap_items << block unless block.inner_html.match("FullProfile").nil?
        end

	html = scrap_items[0].inner_html.gsub("\n", "") # supriming \n makes regexp easier
	scrap_pat = /<div><a href="\/FullProfile\?uid=(\d*?)">(.*?)<\/a>:<span>(.*?)<\/span><div><span>(.*?)<\/span>.*?<hr>/
	raw_scraps = html.scan(scrap_pat)
	scraps = []
	raw_scraps.each do |rs|
		uid = rs[0]
		name = rs[1]
		date = rs[2]
		message = rs[3]
		author = OrkutUser.new(uid, name)
		scraps << Scrap.new(author, date, message)
	end
        return scraps 
      end
      
      def friends() # get your friends
          nodes = []
	  # search friends from 'a' to 'z'
	  for c in 'a'..'z'
		  page = self.get("http://m.orkut.com/ShowFriends?small=#{c}&caps=#{c.capitalize}&pgsize=1000") 
		  page.parser.css("div.mblock").each do |block|
		     nodes << block unless block.inner_html.match("FullProfile").nil?
		  end
	  end
	  # special case: friends names that don't start with letters (c = '*'):
	  page = self.get("http://m.orkut.com/ShowFriends?small=*&caps=*&pgsize=1000") 
	  page.parser.css("div.mblock").each do |block|
	     nodes << block unless block.inner_html.match("FullProfile").nil?
	  end

	  # change html found code into OrkutUser objects
	  user_pat = /FullProfile\?uid=(.*?)">(.*?)<\/a><br>/
	  friends = []
          nodes.each do |f|
	    matcher = user_pat.match(f.inner_html)
	    uid = matcher[1]
           name = matcher[2]
           friends << OrkutUser.new(uid, name)
	  end	  
	  return friends # list of OrkutUser objects
      end

      def friends_of(user=nil) # get friends of other people
          nodes = []
	  if user.nil?
		return nodes
	  end
	  # search friends page by page, advancing through '>' button
	  advance_pat = /<a href="\/FriendsList\?uid=(\d*?)&amp;pno=(\d*?)">&gt;<\/a>$/
	  index = 1
	  loop = true
	  while loop do # while we are not in the last page (the that hasn't the '>')
		  page = self.get("http://m.orkut.com/FriendsList?uid=#{user.uid}&pno=#{index}") 
		  page.parser.css("div.friendlist").each do |block|
		     nodes << block unless block.inner_html.match("FullProfile").nil?
		  end
		  if !advance_pat.match(page.parser.to_s)
			loop = false
		  end
		  index = index + 1
	  end		  

	  # change html found code into OrkutUser objects
	  uid_pat = /FullProfile\?uid=(.*?)">/
	  name_pat = /(.*?)<\/a>/
	  friends = []
          nodes.each do |f|
	     matcher_uid = uid_pat.match(f.inner_html)
	     matcher_name = name_pat.match(f.inner_html)
 	     uid = matcher_uid[1]
             name = matcher_name[1]
             friends << OrkutUser.new(uid, name)
	  end	  
	  return friends # list of OrkutUser objects
      end


      def logout
        raise JumProxy::NotLoggedIn, "You need login before access this resource." unless logged_in?        
        get("http://m.orkut.com/GLogin?cmd=logout")
      end

    end    

	# more classes to orkut: Scrap and OrkutUser
    
	class Scrap
		attr_accessor :author, :date, :message

		def initialize(author, date, message)
			@author = author
			@date = date
			@message = message
		end
		def to_s
			return @author.to_s + ', ' + @date + ': ' + @message 
		end
	end

	class OrkutUser
		attr_accessor :name, :uid

		def initialize(uid, name)
			@name = name
			@uid = uid
		end
		def to_s
			return @name + ' ' + @uid 
		end
	end


    class Twitter < JumProxy::Base
      def initialize(user, pass)
        self.user_input = "session[username_or_email]"
        self.pass_input = "session[password]"
        url = "http://m.twitter.com/login"
        page = self.login(user, pass, url)
        
        unless page.body.match("Wrong Username/Email and password combination").nil?
          raise JumProxy::NotAuthorized, "JumProxy can't login with this credential (#{user})."
        else
          self.logged_in = true
        end
      end
      
      def tweets(user=nil)
        raise JumProxy::NotLoggedIn, "You need login before access this resource." unless logged_in?
        if user.nil?
          url = "http://m.twitter.com/home"
        else
          url = "http://m.twitter.com/#{user}"
        end
        page = self.get(url)        
        tweet_items = []
        page.parser.css("li").each do |block|
          tweet_items << block.content
        end
        return tweet_items
      end
      
      def post(message)
        raise JumProxy::NotLoggedIn, "You need login before access this resource." unless logged_in?
        raise JumProxy::ArgumentInvalid, "Your message is too long (max. 140 chars)." if message.length > 140
        page = self.get("http://m.twitter.com/home")
        form = page.forms.first
        form["status"] = message
        self.agent.submit(form)
      end
    end
    
    class BlogSpot < JumProxy::Base
      def last_posts(url)
      end
      
      def comments(post)
      end
      
      def post_comment(name, email, message)
      end
    end
  end
end
