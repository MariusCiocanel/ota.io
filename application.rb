require 'rubygems'
require 'sinatra'
require 'erb'
require 'json'
require 'data_mapper'
require 'aws/s3'
require 'plist'
require 'set'

development = ENV['DATABASE_URL'] ? false : true

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/appsendr-v2')
if development
    BASE_URL = "http://127.0.0.1:9393"
else 
    BASE_URL = "http://ota.io"
end
ASSET_URL = "http://assets.ota.io"

S3_KEY     = 'AKIAI25H5FVEUIGMP6YQ'
S3_SECRET = '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'
BUCKET = 'ota.io'
S3_URL = "http://s3.amazonaws.com/#{BUCKET}"

LENGTH_OF_HASH = 5


class App
    include DataMapper::Resource
    property :id, String, :required => true, :key=>true
    property :filename, String, :required => true
    property :identifier, String, :required => true
    property :installs, Integer
    property :icon, Boolean
    property :android, Boolean
    
    property :created_at, DateTime
    property :updated_at, DateTime
    
    def install_url
        self.app_url if self.android
        "itms-services://?action=download-manifest&url=#{self.manifest_url}"
    end
    
    def install_track_url
        return BASE_URL+"/r/"+self.id
    end
    
    def manifest_url
        return BASE_URL+"/"+self.id+"/manifest"
    end
    
    def icon_url
        return ASSET_URL+"/app/#{self.id}/icon.png" if self.icon
        return ASSET_URL+"/default.png"
    end
    
    def app_url
        return ASSET_URL+"/app/#{self.id}/#{self.filename}"
    end
    
    def name
        File.basename(self.filename, '.*') 
    end
end

DataMapper.auto_upgrade!


get '/' do
    erb :index
end

get '/all' do
    @apps = App.all
  erb :all
end

post '/app' do
    file_data = nil
    name = nil
    android = false    
    
    response.headers['Content-Type'] = 'application/json'
    
    if params['binary']
        name = params['binary'][:filename]
        return _error("Invalid file type. Must be an IPA or APK",400) unless Set[File.extname(name)].proper_subset? Set[".ipa",".apk"]
        
        android = true if File.extname(name) == "apk"
        file_data = params['binary'][:tempfile].read        
    end
    
    return _error("No binary file provided",400) unless file_data

    
    
    # if params['ipa']
    #     file_data = file[:tempfile].read
    #     name = params['ipa'][:filename]
    # elsif params['apk']
    #     android = true
    #     
    #     file_data = params['apk'][:tempfile].read
    #     name = params['apk'][:filename]
    # end
    
    id = params['identifier']
    key = _generate_hash_id
    
    icon = params['icon']
    if  icon
        icon_data = icon[:tempfile].read
        icon_name = icon[:filename]
        _upload(icon_data,key,icon_name,true)    
    end

    
    app = App.create(
                        :filename=>name, 
                        :identifier=>id, 
                        :id=>key, 
                        :installs=>0, 
                        :icon=>!icon.nil?, 
                        :android=>android,
                        :created_at=>Time.now,
                        :updated_at=>Time.now
                    )
    
    
    if app
        _upload(file_data,key,name)  
        _success({:id=>app.id, :url=>BASE_URL+"/#{app.id}", :filename=>app.filename, :created_at=>app.created_at},201)
    else
        _error("Problem creating app",400)
    end
end


get '/:id/manifest' do
    app = App.get(params[:id])
    status 404 unless app
        
    manifest = {
        :items=>[{
            :assets=>[{
                "kind"=>"software-package",
                "url"=>app.app_url
            },{
                "kind"=>"display-image",
                "needs-shine"=>true,
                "url"=>app.icon_url  
            }
            ],
            :metadata=>{
                "bundle-identifier" => app.identifier,
                "kind"=>"software",
                "subtitle"=>"AppSendr",
                "title"=>app.name
            }
        }]
    }
    
    response.headers['Content-Type'] = 'application/xml'
    
    manifest.to_plist

end


get '/:id' do
    @app = App.get(params[:id])
    status 404 unless @app
    erb :install
end

get '/r/:id' do
    @app = App.get(params[:id])
    status 404 unless @app
    
    @app.installs += 1
    @app.save
    
    redirect @app.install_url
end


private
def _upload(file_data,key,filename, icon=false)
    
	AWS::S3::Base.establish_connection!(
	    :access_key_id => S3_KEY,
	    :secret_access_key => S3_SECRET
	)
	
    ipa_path = icon ? "app/#{key}/icon.png" : "app/#{key}/#{filename}"
    
    AWS::S3::S3Object.store(ipa_path, file_data, BUCKET, :access => :public_read)
end

def _generate_hash_id
    # based on http://erickel.ly/sinatra-url-shortener
    
    # Create an Array of possible characters
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    # Create a random 3 character string from our possible
    # set of choices defined above.
    tmp = chars[rand(62)]
    LENGTH_OF_HASH.times do
        tmp += chars[rand(62)]
    end

    # Until retreiving a Link with this short_url returns
    # false, generate a new short_url and try again.
    until App.get(tmp).nil?
        tmp = chars[rand(62)]
        LENGTH_OF_HASH.times do
            tmp += chars[rand(62)]
        end
    end

    # Return our new unique short_url
    tmp 
end

def _error(message,code)
    status code
    body({:status=>code,:message=>message}.to_json)
end

def _success(data,code)
    status code
    body({:status=>code,:data=>data}.to_json)
end
