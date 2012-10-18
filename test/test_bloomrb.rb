require 'test/unit'
require 'shoulda'
require 'mocha'
require 'bloomrb'

class BloomrbTest < Test::Unit::TestCase
  context "Bloomrb" do

    setup do
      @bloom = Bloomrb.new
      @socket = mock()
      @bloom.stubs(:socket).returns(@socket)
    end

    should "create a filter" do
      @socket.expects(:puts).with("create foobar capacity=1000000 prob=0.001")
      @socket.expects(:gets).returns("Done")

      assert_equal true, @bloom.create('foobar', :capacity => 1000000, :prob => 0.001)
    end

    should "list all filters" do
      @socket.expects(:puts).with("list")
      @socket.stubs(:gets).returns(
        'START',
        'foobar 0.001 1797211 1000000 0',
        'barbaz 0.101 4711 12345 234',
        'END'
      )

      assert_equal [
        {:name => 'foobar', :probability => 0.001, :size => 1797211, :capacity => 1000000, :items => 0},
        {:name => 'barbaz', :probability => 0.101, :size => 4711, :capacity => 12345, :items => 234}
      ], @bloom.list
    end

    should "drop a filter" do
      @socket.expects(:puts).with("drop foobar")
      @socket.expects(:gets).returns("Done")

      assert_equal true, @bloom.drop('foobar')
    end

    should "close a filter" do
      @socket.expects(:puts).with("close foobar")
      @socket.expects(:gets).returns("Done")

      assert_equal true, @bloom.close('foobar')
    end

    should "clear a filter" do
      @socket.expects(:puts).with("clear foobar")
      @socket.expects(:gets).returns("Done")

      assert_equal true, @bloom.clear('foobar')
    end

    should "check an existing key" do
      @socket.expects(:puts).with("c foobar fookey")
      @socket.expects(:gets).returns("Yes")

      assert_equal true, @bloom.check('foobar', :fookey)
    end

    should "check a nonexisting key" do
      @socket.expects(:puts).with("c foobar fookey")
      @socket.expects(:gets).returns("No")

      assert_equal false, @bloom.check('foobar', :fookey)
    end

    should "check multiple keys" do
      @socket.expects(:puts).with("m foobar fookey1 fookey2 fookey3")
      @socket.expects(:gets).returns("No Yes No")

      assert_equal({:fookey1 => false, :fookey2 => true, :fookey3 => false}, 
                   @bloom.multi('foobar', [:fookey1, :fookey2, :fookey3]))
    end

    should "check if any of the keys are there" do
      @socket.expects(:puts).with("m foobar fookey1 fookey2 fookey3")
      @socket.expects(:gets).returns("No Yes No")

      assert_equal true, @bloom.any?('foobar', [:fookey1, :fookey2, :fookey3])
    end

    should "check if all of the keys are there" do
      @socket.expects(:puts).with("m foobar fookey1 fookey2 fookey3")
      @socket.expects(:gets).returns("No Yes No")

      assert_equal false, @bloom.all?('foobar', [:fookey1, :fookey2, :fookey3])
    end

    should "set a key" do
      @socket.expects(:puts).with("s foobar fookey")
      @socket.expects(:gets).returns("No")

      assert_equal false, @bloom.set('foobar', :fookey)
    end

    should "bulk set keys" do
      @socket.expects(:puts).with("b foobar fookey1 fookey2 fookey3")
      @socket.expects(:gets).returns("No Yes No")

      assert_equal 'No Yes No', @bloom.bulk('foobar', [:fookey1, :fookey2, :fookey3])
    end

    should "return an info hash" do
      @socket.expects(:puts).with("info foobar")
      @socket.stubs(:gets).returns(
        'START',
        'capacity 1000000',
        'checks 0',
        'check_hits 0',
        'check_misses 0',
        'page_ins 0',
        'page_outs 0',
        'probability 0.001',
        'sets 0',
        'set_hits 0',
        'set_misses 0',
        'size 0',
        'storage 1797211',
        'END')

      assert_equal({
        'capacity' => '1000000',
        'checks'  => '0',
        'check_hits' => '0',
        'check_misses' => '0',
        'page_ins' => '0',
        'page_outs' => '0',
        'probability' => '0.001',
        'sets' => '0',
        'set_hits' => '0',
        'set_misses' => '0',
        'size' => '0',
        'storage' => '1797211'}, @bloom.info('foobar'))
    end

    should "retry" do
      @bloom.expects(:sleep).with(1)
      @socket.expects(:puts).twice.with("s foobar fookey")
      @socket.expects(:gets).twice.raises(Errno::ECONNRESET).then.returns("No")

      assert_equal false, @bloom.set('foobar', :fookey)
    end

    should "raise after 5 retries" do
      @bloom.expects(:sleep).times(4).with(1)
      @socket.expects(:puts).times(5).with("s foobar fookey")
      @socket.expects(:gets).times(5).raises(Errno::ECONNRESET)

      assert_raises Errno::ECONNRESET do
        @bloom.set('foobar', :fookey)
      end
    end
  end
end
