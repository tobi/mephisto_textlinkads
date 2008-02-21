require 'net/http'
require 'cgi'


module MephistoPlugins
  module TextLinkAds    
    mattr_accessor :affiliate_number
    self.affiliate_number = 20722
   
    class Server
      class Url < Struct.new(:expiry, :value)
        def expired?
          expiry <= Time.now
        end
      end      
      
      def initialize(ttl)
        @ttl    = ttl
        @cache  = Hash.new        
      end

      def fetch(url)
        if @cache.has_key?(url) and not @cache[url].expired?
          return @cache[url].value 
        end
        
        xml = http_get(url)          
        if xml
          url = Url.new(@ttl.from_now, xml)
          @cache[url] = url
          return url.value
        else
          nil
        end                  
      end

      private
      
      def http_get(url)
        Timeout::timeout(20.0) do          
          XmlSimple.xml_in(Net::HTTP.get_response(URI.parse(url)).body.to_s)
        end
      rescue StandardError, RuntimeError
        nil
      end

    end
    
    
    include ActionView::Helpers::JavascriptHelper

    def textlinkads(key)
      req = @context.registers[:controller].request
      url = "http://www.text-link-ads.com/xml.php?inventory_key=#{key}&referer=#{CGI::escape(req.env['REQUEST_URI'])}&user_agent=#{CGI::escape(req.env['HTTP_USER_AGENT'])}"
      
      if response = server.fetch(url)

        response['Link'].collect do |link|
          content_tag :li, %(#{link['BeforeText'].first} <a href="#{link['URL'].first}" title="#{link['Text'].first}">#{link['Text'].first}</a> #{link['AfterText'].first})
        end.join("\n\t")
        
      end      
    rescue 
      "<li><a href=\"http://www.text-link-ads.com/?ref=#{affiliate_number}\">Buy links here</a></li>"      
    end
    
    private
    
    def server
      $server ||= Server.new( 60.minutes )
    end

  end
end
