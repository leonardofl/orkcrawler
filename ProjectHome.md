**ORK CRAWLER**

This is a library based on http://gist.github.com/104221.

With this Ruby library you can crawler for:

- twits

- Orkut user's scraps

- Orkut user's friends

TODO: crawler for more scraps than only the first page and crawler for Orkut communities.

Atention: Ork Crawler is licensed under GPLv3, what does mean that the library can be used only by software that are licensed under "GPLv3" or "GPLv2 or later" (or, of course "GPLv3 or later").

Example of usage:

```

require 'jum_proxy'

if __FILE__ == $0

	orkut = JumProxy::Sites::Orkut.new("orkutuser@gmail.com", "PASSWORD", "pt-BR")
        some_uid_user = '16205345908980793628'
	bob = JumProxy::Sites::OrkutUser.new(some_uid_user, 'a name')

	puts 'My scraps...'
	scraps = orkut.scraps
	scraps.each do |s|
		puts s
		puts "*****************"
	end

	puts 'Bob scraps...'
	scraps = orkut.scraps(bob)
	scraps.each do |s|
		puts s
		puts "*****************"
	end


	puts 'My friends...'
	friends = orkut.friends
	friends.each do |f|
		puts f 
	end

        puts "*******************"

	puts 'Bob friends...'
	friends = orkut.friends_of(bob)
	friends.each do |f|
		puts f 
	end

```