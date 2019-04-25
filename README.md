# cartodb-common

Ruby gem with common tools for (CartoDB)[https://github.com/CartoDB/cartodb]

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cartodb-common'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cartodb-common

## Usage

First: 
`require 'cartodb-common'`

### Encryption

Encrypt with Argon2:
`Carto::Common::EncryptionService.new.encrypt(password: "my_password")`

Verify a password:
`Carto::Common::EncryptionService.new.verify(password: "my_password", secure_password: "e4c2a6d7d41e6170470a9d1d3234bdcbc1b95018")`

Create a random token:
`Carto::Common::EncryptionService.new.make_token`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake build`, which will build a local copy of the gem in in `/pkg`

## Contributing

See [our contributing doc](CONTRIBUTING.md) for how you can improve cartodb-common, but you will need to sign a Contributor License Agreement (CLA) before making a submission, [learn more here](https://carto.com/contributions).
