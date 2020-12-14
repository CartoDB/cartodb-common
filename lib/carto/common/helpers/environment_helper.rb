module EnvironmentHelper

  def development_environment?
    rails_env.casecmp('development').zero?
  end

  def test_environment?
    rails_env.casecmp('test').zero?
  end

  def staging_environment?
    rails_env.casecmp('staging').zero?
  end

  def production_environment?
    rails_env.casecmp('production').zero?
  end

  private

  def rails_env
    ENV['RAILS_ENV'].to_s
  end

end
