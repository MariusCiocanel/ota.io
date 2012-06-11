require 'application'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class HelloWorldTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_app
    get '/'
    assert last_response.ok?
    assert_equal 'Hello World', last_response.body
  end

end