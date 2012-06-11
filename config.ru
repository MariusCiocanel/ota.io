require './application'

development = ENV['DATABASE_URL'] ? false : true # running on heroku

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/otaio')

S3_KEY     = '<YOUR KEY>'
S3_SECRET = '<YOUR SECRET>'
S3_BUCKET = '<YOUR BUCKET>'
S3_URL = "http://s3.amazonaws.com/#{BUCKET}"

LENGTH_OF_HASH = 5

run Sinatra::Application