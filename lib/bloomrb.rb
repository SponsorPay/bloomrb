require 'socket'

class Bloomrb
  class Error < StandardError; end

  attr_accessor :host, :port, :retries

  def initialize(host = 'localhost', port = 8673, retries = 5)
    self.host    = host
    self.port    = port
    self.retries = retries
  end

  def socket
    @socket ||= TCPSocket.new(host, port).tap do |socket|
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    end
  end

  def disconnect
    @socket.close if @socket
    @socket = nil
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
    return Hash.new if keys.empty?

    Hash[keys.zip(execute('m', filter, *keys).split(' ').map{|r| r == 'Yes'})]
  end

  def any?(filter, keys)
    return false if keys.empty?

    !!(execute('m', filter, *keys) =~ /Yes/)
  end

  def all?(filter, keys)
    return true if keys.empty?

    !!(execute('m', filter, *keys) !~ /No/)
  end

  def set(filter, key)
    execute('s', filter, key) == 'Yes'
  end

  def bulk(filter, keys)
    return "" if keys.empty?

    execute('b', filter, *keys)
  end

  def info(filter)
    Hash[execute('info', filter).map{|s| s.split(' ')}]
  end

  def flush(filter = nil)
    execute('flush', filter) == 'Done'
  end

  protected

  ERROR_RESPONSE_MATCHERS = [
    /Filter does not exist/,
    /^Client Error:/
  ].freeze

  def error?(result)
    ERROR_RESPONSE_MATCHERS.any? { |matcher| result =~ matcher }
  end

  def execute *args
    opts = Hash === args.last ? args.pop : {}
    args.compact!

    cmd = args.join(' ')
    cmd += ' ' + opts.map{|k, v| "#{k}=#{v}"}.join(' ') unless opts.empty?

    retry_count = 0
    begin
      socket.puts(cmd)
      result = socket.gets.chomp
      raise Error, "#{result}: #{cmd[0..99]}" if error?(result)

      if result == 'START'
        result = []
        while (s = socket.gets.chomp) != 'END'
          result << s
        end
      end
      result
    rescue Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ECONNREFUSED, Errno::EPIPE
      raise if (retry_count += 1) >= retries
      @socket = nil
      sleep(1)
      retry
    end
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
