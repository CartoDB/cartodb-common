require_relative 'argon2_encryption_strategy'
require_relative 'sha_encryption_strategy'
require 'securerandom'

module Carto
  module Common
    class EncryptionService

      DEFAULT_TOKEN_LENGTH = 40

      def self.encrypt(password:, sha_class: nil, salt: nil, secret: nil)
        strategy = sha_class ? ShaEncryptionStrategy : Argon2EncryptionStrategy
        strategy.encrypt(password: password, sha_class: sha_class, salt: salt, secret: secret)
      end

      def self.verify(password:, secure_password:, salt: nil, secret: nil)
        strategy = argon2?(secure_password) ? Argon2EncryptionStrategy : ShaEncryptionStrategy
        strategy.verify(password: password, secure_password: secure_password, salt: salt, secret: secret)
      end

      def self.make_token(length: DEFAULT_TOKEN_LENGTH)
        SecureRandom.hex(length / 2)
      end

      def self.argon2?(encryption)
        encryption =~ /^\$argon2/
      end

      def self.hex_digest(encryption)
        return ShaEncryptionStrategy.encrypt(password: encryption) if argon2?(encryption)

        encryption
      end

    end
  end
end
