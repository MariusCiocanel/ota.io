require 'rubygems'
require 'sinatra'
require 'erb'
require 'json'


enable :sessions

get '/' do
  redirect '/index.html'
end