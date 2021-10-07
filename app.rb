require 'sinatra'
require 'json'
require 'google/cloud/storage'
require 'digest'

storage = Google::Cloud::Storage.new(project_id: 'cs291a')
$bucket = storage.bucket 'cs291project2', skip_lookup: true

def is256bit_hex digest
  if (digest.match /^\h{64}$/).nil?
    return false
  end
  true
end

def getBucketObjNames
  a = []
  #files   = bucket.files prefix: prefix, delimiter: delimiter
  $bucket.files.each do |file|
    name = file.name.delete('/').downcase
    if is256bit_hex(name)
      a<<name
    end
  end
  a.sort()
end

get '/' do
  status 302
  redirect to('/files/')
end

get '/files/' do
  status 200
  content_type :json
  getBucketObjNames().to_json
end

post '/files/' do

  begin 
    file_path = params[:file][:tempfile].path
    file_name = params[:file][:filename]
  rescue
    return status 422
  end

  if file_path.nil?||File.size(file_path) > 1024*1024
    return status 422
  else 
    hash = (Digest::SHA256.hexdigest(File.read(file_path))).downcase
    
    if getBucketObjNames().include?(hash)
      status 409
      puts "Error 409: A file with the same SHA256 hex digest has already been uploaded."
      return

    else
      status 201    
      objName = hash.dup
      objName.insert(2,"/").insert(5,"/")
      # Upload file to Google Cloud Storage bucket
      file = $bucket.create_file file_path, objName  
      file.content_type = params[:file][:type]   
      json = {'uploaded'=>hash}.to_json
    end
  end
end

get '/files/:digest' do
  digest = params['digest'].downcase
  if !is256bit_hex(digest)
    status 422
    return puts "Not valid sha256 hex digest."
  elsif !getBucketObjNames().include?(digest)
    status 404
    return puts "File not found."
  else
    status 200
    file = $bucket.file digest.insert(2,'/').insert(5,'/')
    headers "Content-Type"=> file.content_type
    downloaded = file.download
    downloaded.rewind
    body downloaded.read
  end
end

delete '/files/:digest' do
  digest = params['digest'].downcase
  if !is256bit_hex(digest)
    status 422
    return puts "Not valid sha256 hex digest."
  elsif !getBucketObjNames().include?(digest)
    status 200
    return 
  else
    status 200
    file = $bucket.file digest.insert(2,'/').insert(5,'/')
    file.delete
  end
end
