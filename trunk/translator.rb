# encoding: UTF-8

require 'rubygems' 
require 'open-uri'
require 'nokogiri'


language = ARGV[0]
word      = ARGV[1]
translated_to = ARGV[2]

doc = Nokogiri::HTML(open("http://#{language}.wikipedia.org/wiki/#{word}"))

acc = Hash.new
doc.css("li[class^='interwiki'] a").each do |link|
  regex = /http\:\/\/([a-z]+)\.wikipedia\.org\/wiki\/([a-zA-ZéúíóáÉÚÍÓÁèùìòàÈÙÌÒÀõãñÕÃÑêûîôâÊÛÎÔÂëÿüïöäËYÜÏÖÄ]+)/
  result = regex.match URI.unescape link.attributes['href'].to_s
  acc[result[1]] = result[2] if result
end

puts "input language(#{language})- #{word} ===> #{acc[translated_to]} (#{translated_to})" 
