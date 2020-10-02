require 'spec_helper'

RSpec.describe Carto::Common::EncryptionService do
  before(:all) do
    @service = Carto::Common::EncryptionService
    @password = 'location'
    @salt = '98dffcb748fc487987af5774ec3aab2d106e8578'
    # "location" encrypted with different methods
    @argon2 = '$argon2id$v=19$m=65536,t=2,p=1$slA4QxnG7HRZoU8h0om3wQ$uHSuZsbyIX0ZHe01lsFn/NgBdlroxJUKjdiasKoZSZU'
    @sha1 = 'e4c2a6d7d41e6170470a9d1d3234bdcbc1b95018'
    @sha256 = 'c419d4097e20c71e76f09a5640cd095aba019198c34439b71e63146f15de7c34'
  end

  describe '#encrypt' do
    it 'uses Argon2 by default' do
      result = @service.encrypt(password: @password)
      expect(result).to match(/^\$argon2/)
      expect(result.length).to eql 97
    end

    it 'returns a different output each time' do
      result1 = @service.encrypt(password: @password)
      result2 = @service.encrypt(password: @password)
      expect(result1).to_not eql result2
    end

    it 'allows to use SHA1' do
      result = @service.encrypt(password: @password, sha_class: Digest::SHA1, salt: 'himalayan')
      expect(result).to match(/\h{40}$/)
    end

    it 'allows to use SHA256' do
      result = @service.encrypt(password: @password, sha_class: Digest::SHA256, salt: 'himalayan')
      expect(result).to match(/\h{64}$/)
    end
  end

  describe '#verify' do
    context 'with Argon2' do
      it 'returns true if the encryption matches' do
        result = @service.verify(password: @password, secure_password: @argon2)
        expect(result).to be true
      end

      it 'returns false if the encryption does not match' do
        result = @service.verify(password: 'other', secure_password: @argon2)
        expect(result).to be false
      end

      it 'returns false if there is no password' do
        result = @service.verify(password: nil, secure_password: @argon2)
        expect(result).to be false
      end

      it 'returns false if there is no encrypted password' do
        result = @service.verify(password: @password, secure_password: nil)
        expect(result).to be false
      end

      it 'verifies passwords encrypted by the service' do
        encrypted = @service.encrypt(password: 'wadus')
        result = @service.verify(password: 'wadus', secure_password: encrypted)
        expect(result).to be true
      end

      it 'verifies passwords encrypted by the service with a secret' do
        encrypted = @service.encrypt(password: 'wadus', secret: 'women')
        result = @service.verify(password: 'wadus', secure_password: encrypted, secret: 'women')
        expect(result).to be true
      end

      it 'returns false if the secret is wrong' do
        encrypted = @service.encrypt(password: 'wadus', secret: 'women')
        result = @service.verify(password: 'wadus', secure_password: encrypted, secret: 'men')
        expect(result).to be false
      end
    end

    shared_examples 'SHA password' do
      it 'returns true if the encryption matches' do
        result = @service.verify(password: @password, secure_password: @sha_password, salt: @salt)
        expect(result).to be true
      end

      it 'returns false if the encryption does not match' do
        result = @service.verify(password: 'other', secure_password: @sha_password, salt: @salt)
        expect(result).to be false
      end

      it 'verifies passwords encrypted by the service' do
        encrypted = @service.encrypt(password: 'wadus', sha_class: @sha_class, salt: 'himalayan')
        result = @service.verify(password: 'wadus', secure_password: encrypted, salt: 'himalayan')
        expect(result).to be true
      end
    end

    context 'with SHA1' do
      before(:all) do
        @sha_password = @sha1
        @sha_class = Digest::SHA1
      end

      it_behaves_like 'SHA password'
    end

    context 'with SHA1 in new format' do
      before(:all) do
        @sha_password = "$sha$v=1$$#{@salt}$#{@sha1}"
        @sha_class = Digest::SHA1
      end

      it_behaves_like 'SHA password'
    end

    context 'with SHA256' do
      before(:all) do
        @sha_password = @sha256
        @sha_class = Digest::SHA256
      end

      it_behaves_like 'SHA password'
    end

    context 'with SHA256 in new format' do
      before(:all) do
        @sha_password = "$sha$v=256$$#{@salt}$#{@sha256}"
        @sha_class = Digest::SHA256
      end

      it_behaves_like 'SHA password'
    end
  end

  describe '#make_token' do
    it 'creates a random token with 40 characters by default' do
      result = @service.make_token
      expect(result.length).to eql 40
    end

    it 'returns a different output each time' do
      result1 = @service.make_token
      result2 = @service.make_token
      expect(result1).to_not eql result2
    end

    it 'creates a random token with custom length' do
      result = @service.make_token(length: 64)
      expect(result.length).to eql 64
    end
  end

  describe '#hex_digest' do
    it 'returns the same value for SHA1 passwords' do
      result = @service.hex_digest(@sha1)
      expect(result).to eql @sha1
    end

    it 'returns the same value for SHA256 passwords' do
      result = @service.hex_digest(@sha256)
      expect(result).to eql @sha256
    end

    it 'returns a SHA1 hash for Argon2 passwords' do
      result = @service.hex_digest(@argon2)
      expect(result).to eql 'f6b9551f0c30c1caa6837ec482729e569bff0cee'
    end
  end
end
