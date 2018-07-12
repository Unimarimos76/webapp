require 'sinatra'
require 'sinatra/reloader'
require 'mysql2'
require 'mysql2-cs-bind'
require 'pry'
require 'openssl'

def client
client = Mysql2::Client.new(
    host: 'localhost',
    port: 3306,
    username: 'root',
    password: '',
    database: 'my_web',
    reconnect: true,
    )
end

def set_user(user_id)
  return nil if user_id.nil?
  @user = db.xquery("SELECT * From user WHERE id = ?", user_id).first.to_a
end

def login?
  !session[:user_id].nil?
end

def check_user
  if session[:user_id].nil?
    redirect '/login'
  end
end

def encrypt(data)
  cipher = OpenSSL::Cipher::Cipher.new("AES-256-CBC")
  cipher.encrypt
  cipher.pkcs5_keyivgen('something')
  enc = cipher.update(data) + cipher.final
  return enc.force_encoding('UTF-8').unpack("H*")[0]
end

def decrypt(data)
  cipher = OpenSSL::Cipher::Cipher.new("AES-256-CBC")
  cipher.decrypt
  cipher.pkcs5_keyivgen('something')
  d = []
  d.push(data)
  dec = cipher.update(d.pack("H*")) + cipher.final
  return dec
end

class Myapp < Sinatra::Base
  # ... アプリケーションのコードを書く ...
  configure :development do
  register Sinatra::Reloader
  enable :sessions
  end


  set :public_folder, File.dirname(__FILE__) + '/public'



#新規登録にかかわらず表示されるところ
  get '/' do
    check_user
    erb :top
  end


#ログイン画面

  get '/login' do
    set_user = params[:user_id]
    erb :login
  end

  get '/login' do
    redirect '/' if login?

    erb :login
  end

  post '/login' do

    email = params[:email]
    password= encrypt(params[:password])

    user = client.xquery("SELECT * FROM user WHERE email = ? and password = ?", email, password).first

    if user
      session[:user_id] = user['user_id']
      redirect '/about'
    else
      erb :login
    end
  end

  #ログインした時に最初に出る画面
get '/about' do
  check_user
  erb :about
end



#ログインの時にチェックされるところ
get '/' do
  check_user
  erb :login
end

#新規登録するところ
  get '/register' do
    erb :register
  end

  post '/register' do
    query = 'INSERT INTO user (email,password) VALUES (?,?)'
    client.xquery(query, params[:email], encrypt(params[:password]))
    session[:user_id] = client.last_id

    redirect to('/')
  end


#全体の画像
  get '/manage' do
    check_user
    @show = client.xquery('SELECT * FROM shows')
    erb :manage
  end

#自分の投稿したもの
  get '/manage/:user_id' do
    check_user
    @show = client.xquery('SELECT * FROM shows where email = ?', params[:email]).first
    erb :manage
  end



#新規投稿するところ
  get '/new' do
    check_user
    erb :new
  end

  post '/new' do
    check_user

    @filename = params[:file][:filename]
    file = params[:file][:tempfile]

    # 画像をディレクトリに配置
    File.open("./public/img/#{@filename}", 'wb') do |f|
      f.write(file.read)
    end

    query = 'INSERT INTO shows (image_path,title,description) VALUES (?,?,?)'
    @show = client.xquery(query ,"/img/#{@filename}",params[:title],params[:description])

    redirect to('/manage')

  end
#画像をけす
  post '/destroy/:id' do
    query = 'DELETE FROM shows WHERE id = ?'
    client.xquery(query, params[:id])

    redirect to('/manage')
  end

#画像を編集する

  get '/edit/:id' do

    @show = client.xquery('SELECT * FROM shows WHERE id = ?', params[:id]).first

    erb :edit
  end

  post '/edit/:id' do

    # 画像情報を取得
    @filename = params[:file][:filename]
    file = params[:file][:tempfile]


    # 画像をディレクトリに配置
    File.open("./public/img/#{@filename}", 'wb') do |f|
      f.write(file.read)
    end

    query = 'UPDATE shows SET image_path=?, title=?, description=? WHERE id = ?'
    client.xquery(query, "/img/#{@filename}",params[:title],params[:description],params[:id])

    redirect to('/manage')
  end

  get '/logout' do
    session[:user_id] = nil
    redirect '/'
  end
end






