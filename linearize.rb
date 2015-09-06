#!/usr/bin/ruby
$LOAD_PATH.unshift File.dirname(__FILE__)
require 'bitcoin_rpc'

def sub(d, start, depth, bootstrap, minconf, netmagic)
  netmagicbin = [netmagic].pack('H*')
  uri = "http://#{d['user']}:#{d['password']}@#{d['host']}:#{d['port']}"
  rpc = BitcoinRPC.new(uri)
  info = rpc.getinfo
  blocks = info['blocks']
  (start..depth).each do |i|
    puts i if i % 1000 == 0
    height = i
    hash = rpc.getblockhash(height)
    rawblock = rpc.getblock(hash, false)
    rawblock = [rawblock].pack("H*")
    bootstrap.write(netmagicbin)
    bootstrap.write([rawblock.size].pack('V'))
    bootstrap.write(rawblock)
  end
  {'blocks' => depth}
end

config = YAML.load_file('config.yml')
coinids = config['coins'].keys.sort_by(&:to_s)
coinids.each do |coinid|
  coin = config['coins'][coinid]
  user = coin['user']
  password = coin['password']
  host = coin['host']
  port = coin['port']
  name = coin['name']
  minconf = coin['minconf'] || 6
  netmagic = coin['netmagic']
  bootfile = "#{name}_bootstrap.dat"
  resumefile = "#{bootfile}.resume"
  File.open(bootfile, "ab") do |bootstrap|
    if File.exist?(resumefile)
      json = File.open(resumefile, "r"){|fd|fd.read}
      state = JSON.parse(json)
    end
    start = state ? state['blocks'] + 1 : 0
    endblk = start + 10000
    depth = sub({
      'user' => user,
      'password' => password,
      'host' => host,
      'port' => port,
    }, start, endblk, bootstrap, minconf, netmagic)
    File.open(resumefile, "w") do |resume|
      resume.write(depth.to_json)
      resume.puts
    end
  end
end
