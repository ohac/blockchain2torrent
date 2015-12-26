# blockchain2torrent

Copy config file template

    $ cp example-config.yml config.yml
    $ vi config.yml

Edit config.yml

example:

    coins:
      monacoin:
        user: u
        password: p
        host: 127.0.0.1
        port: 9402
        name: Monacoin
        netmagic: fbc0b6db TODO

Execute linearize.rb

    $ bundle exec ruby linearize.rb
