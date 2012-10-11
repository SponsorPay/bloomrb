require 'socket'

class Bloomrb
  attr_accessor :host, :port

  def initialize(host = 'localhost', port = 8673)
    self.host = host
    self.port = port
  end

  def socket
    @socket ||= TCPSocket.new(host, port)
  end

  def filter(name)
    BloomFilter.new(name, self)
  end

  def create(filter, opts = {})
    execute('create', filter, opts) == 'Done'
  end

  def list
    execute('list').map do |line|
      name, probability, size, capacity, items = line.split(' ')
      {:name => name,
       :probability => probability.to_f,
       :size => size.to_i,
       :capacity => capacity.to_i,
       :items => items.to_i}
    end
  end

  def drop(filter)
    execute('drop', filter) == 'Done'
  end

  def close(filter)
    execute('close', filter) == 'Done'
  end

  def clear(filter)
    execute('clear', filter) == 'Done'
  end

  def check(filter, key)
    execute('c', filter, key) == 'Yes'
  end

  def multi(filter, keys)
    Hash[keys.zip(execute('m', filter, *keys).split(' ').map{|r| r == 'Yes'})]
  end
  
  def any?(filter, keys)
    !!(execute('m', filter, *keys) =~ /Yes/)
  end

  def all?(filter, keys)
    !!(execute('m', filter, *keys) !~ /No/)
  end

  def set(filter, key)
    execute('s', filter, key) == 'Yes'
  end

  def bulk(filter, keys)
    execute('b', filter, *keys)
  end

  def info(filter)
    Hash[execute('info', filter).map{|s| s.split(' ')}]
  end

  def flush(filter = nil)
    execute('flush', filter) == 'Done'
  end

  protected

  def execute *args
    opts = Hash === args.last ? args.pop : {}
    args.compact!

    cmd = args.join(' ')
    cmd += ' ' + opts.map{|k, v| "#{k}=#{v}"}.join(' ') unless opts.empty?
    
    socket.puts(cmd)
    result = socket.gets.chomp
    throw result if result =~ /^Client Error:/

    if result == 'START'
      result = []
      while (s = socket.gets.chomp) != 'END'
        result << s
      end
    end
    result
  end
end

class BloomFilter
  attr_accessor :name, :bloormrb

  def initialize(name, bloormrb)
    self.name = name
    self.bloormrb = bloormrb
  end

  protected

  def self.delegate method
    define_method(method) do |*args|
      bloormrb.send(method, name, *args)
    end
  end

  delegate :create
  delegate :drop
  delegate :close
  delegate :clear
  delegate :check
  delegate :multi
  delegate :any?
  delegate :all?
  delegate :set
  delegate :bulk
  delegate :info
  delegate :flush
end
