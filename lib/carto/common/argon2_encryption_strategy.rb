require 'argon2'

module Carto
  module Common
    class Argon2EncryptionStrategy

      def self.encrypt(password:, secret: nil, **_)
        argon2 = Argon2::Password.new(secret: secret)
        argon2.create(password)
      end

      def self.verify(password:, secure_password:, secret: nil, **_)
        Argon2::Password.verify_password(password, secure_password, secret)
      end

    end
  end
end
