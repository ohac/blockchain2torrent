#!/usr/bin/ruby
$LOAD_PATH.unshift File.dirname(__FILE__)
require 'bitcoin_rpc'
require 'digest/sha1'
require 'bencode'

def sub(d, start, depth, bootstrap, filesize)
  netmagic = d['netmagic']
  netmagicbin = [netmagic].pack('H*')
  uri = "http://#{d['user']}:#{d['password']}@#{d['host']}:#{d['port']}"
  rpc = BitcoinRPC.new(uri)
  info = rpc.getinfo
  blocks = info['blocks']
  minconf = d['minconf'] || 6
  blocks -= minconf
  (start..depth).each do |i|
    puts i if i % 1000 == 0
    height = i
    hash = rpc.getblockhash(height)
    rawblock = rpc.getblock(hash, false)
    rawblock = [rawblock].pack("H*")
    bootstrap.write(netmagicbin)
    s = rawblock.size
    bootstrap.write([s].pack('V'))
    bootstrap.write(rawblock)
    filesize += 8 + s
  end
  {'blocks' => depth, 'filesize' => filesize}
end

def update_torrent(coin, height, filesize, bootfile)
  name = coin['name']
  tr = {}
  tr["announce-list"] = [
    ["udp://tracker.openbittorrent.com:80"],
    ["udp://tracker.publicbt.com:80"],
    ["udp://coppersurfer.tk:6969/announce"],
    ["udp://open.demonii.com:1337"],
    ["http://bttracker.crunchbanglinux.org:6969/announce"]
  ]
  tr["announce"] = tr["announce-list"].first
  tr["comment"] = "#{name} blockchain @ #{height}"
  tr["created by"] = "blockchain2torrent"
  tr["creation date"] = Time.now.to_i
  tr["encoding"] = "UTF-8"
  info = {}
  tr["info"] = info
  info["length"] = filesize
  info["name"] = "bootstrap.dat"
  piece_len = 2 * 1024 * 1024
  info["piece length"] = piece_len
  info["private"] = 0
  pieces = ''
  File.open(bootfile, "rb") do |fd|
    while piece = fd.read(piece_len) do
      pieces += Digest::SHA1.digest(piece)
    end
  end
  info["pieces"] = pieces
  File.open("#{name}_bootstrap.dat.torrent", 'wb') do |fd|
    fd.write(BEncode.dump(tr))
  end
end

config = YAML.load_file('config.yml')
coinids = config['coins'].keys.sort_by(&:to_s)
coinids.each do |coinid|
  coin = config['coins'][coinid]
  name = coin['name']
  bootfile = "#{name}_bootstrap.dat"
  resumefile = "#{bootfile}.resume"
  start = 0
  filesize = File.size(bootfile) rescue 0
  if File.exist?(resumefile)
    json = File.open(resumefile, "r"){|fd|fd.read}
    state = JSON.parse(json)
    start = state['blocks'] + 1
    filesize = state['size'] || filesize
  end
  endblk = start + 2000
  File.open(bootfile, "ab") do |bootstrap|
    state = sub(coin, start, endblk, bootstrap, filesize)
    File.open(resumefile, "w") do |resume|
      resume.write(state.to_json)
      resume.puts
    end
  end
  update_torrent(coin, state['blocks'], state['filesize'], bootfile)
end
