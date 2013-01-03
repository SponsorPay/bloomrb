BloomRB
=======

This is a Ruby client for the [bloomd server](https://github.com/armon/bloomd).

Installation
------------

``` ruby
gem install bloomrb
```

If you want to run tests:

```
git clone git://github.com/SponsorPay/bloomrb.git
cd bloomrb
bundle
rake test
```

Usage
-----

All the commands from bloomd [protocol](https://github.com/armon/bloomd#protocol) are wrapped in a method with the same name. Return values are converted to Ruby types (e.g. `true`/`false` instead of `Yes`/`No`)

``` ruby
1.9.2p180 :001 > require 'bloomrb'
 => true

1.9.2p180 :002 > bloom = Bloomrb.new
 => #<Bloomrb:0x0000000151a760 @host="localhost", @port=8673>

1.9.2p180 :003 > bloom.create('awesome')
 => true

1.9.2p180 :004 > bloom.check('awesome', :foo)
 => false

1.9.2p180 :007 > bloom.set('awesome', :foo)
 => true

1.9.2p180 :008 > bloom.check('awesome', :foo)
 => true

1.9.2p180 :010 > bloom.multi('awesome', [:bar, :foo, :baz])
 => {:bar=>false, :foo=>true, :baz=>false}

1.9.2p180 :014 > bloom.bulk('awesome', [:barbaz, :foobar, :bazbaz])
 => "Yes No Yes"

1.9.2p180 :017 > bloom.multi('awesome', [:barbaz, :foobar, :bazbaz])
 => {:barbaz=>true, :foobar=>true, :bazbaz=>true}

1.9.2p180 :018 > bloom.list
 => [{:name=>"awesome", :probability=>0.0001, :size=>300046, :capacity=>100000, :items=>6}]

1.9.2p180 :019 > bloom.info('awesome')
 => {"capacity"=>"100000", "checks"=>"17", "check_hits"=>"10", "check_misses"=>"7", "page_ins"=>"0", "page_outs"=>"0", "probability"=>"0.000100", "sets"=>"7", "set_hits"=>"6", "set_misses"=>"1", "size"=>"6", "storage"=>"300046"}
```

There are two convenience methods `all?` and `any?` that makes life a bit easier when dealing with multi based operations.

``` ruby
1.9.2p180 :011 > bloom.any?('awesome', [:bar, :foo, :baz])
 => true

1.9.2p180 :012 > bloom.all?('awesome', [:bar, :foo, :baz])
 => false
```
