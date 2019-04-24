require 'digest'

module Carto
  module Common
    class ShaEncryptionStrategy

      AUTH_DIGEST_KEYS = {
        Digest::SHA1 => '47f940ec20a0993b5e9e4310461cc8a6a7fb84e3',
        Digest::SHA256 => '1211b3e77138f6e1724721f1ab740c9c70e66ba6fec5e989bb6640c4541ed15d06dbd5fdcbd3052b'
      }.freeze

      DEFAULT_SHA_CLASS = Digest::SHA1      

      def self.encrypt(password:, salt: nil, sha_class: DEFAULT_SHA_CLASS, **_)
        args = [salt, password].compact
        digest_key = AUTH_DIGEST_KEYS[sha_class]
        digest = digest_key
        args_join = '--' if sha_class == Digest::SHA1

        10.times do
          joined_args = [digest, args, digest_key].flatten.join(args_join)
          digest = sha_class.hexdigest(joined_args)
        end
        digest
      end

      def self.verify(password:, secure_password:, salt: nil, **_)
        sha_class = sha_class(secure_password)
        return false unless sha_class

        if secure_password =~ /^\$sha/
          digest_from_encryption = secure_password.split('$')[-1]
          salt_from_encryption = secure_password.split('$')[-2]
          digest_from_encryption == encrypt(password: password, salt: salt_from_encryption, sha_class: sha_class)
        else
          secure_password == encrypt(password: password, salt: salt, sha_class: sha_class)
        end
      end

      def self.sha_class(secure_password)
        case secure_password
        when /^\$sha\$v=1/ then Digest::SHA1
        when /^\h{40}$/ then Digest::SHA1
        when /^\$sha\$v=256/ then Digest::SHA256
        when /^\h{64}$/ then Digest::SHA256
        end
      end

    end
  end
end
