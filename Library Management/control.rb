require 'sinatra'
require 'data_mapper'
require 'json'

enable :sessions
DataMapper::setup(:default, "mysql://root:password@localhost/db")

class Book
  include DataMapper::Resource
  property :id, Serial
  property :title, Text, :required => true
  property :publisher, Text, :required => true
  has n, :authorships, :constraint => :destroy
  has n, :authors, :through => :authorships
  has n, :checkouts, :constraint => :destroy
  has 1, :customer, :through => :checkouts
end

class Authorship
  include DataMapper::Resource
  belongs_to :author, :key => true
  belongs_to :book, :key => true
end

class Author
  include DataMapper::Resource
  property :id, Serial
  property :name, Text, :required => true
  has n, :authorships, :constraint => :destroy
  has n, :books, :through => :authorships
end

class Customer 
  include DataMapper::Resource
  property :id, Serial
  property :firstname, Text
  property :lastname, Text
  property :registration, Date, :required => true
  has n, :checkouts, :constraint => :destroy
  has n, :books, :through => :checkouts
end

class Checkout
  include DataMapper::Resource
  property :id, Serial
  property :checkoutdate, Date
  property :purchasedate, Date
  property :returndate, Date
  property :reserveddate, Date
  property :returned, Boolean
  property :current, Boolean
  belongs_to :book, :key => true
  belongs_to :customer, :key => true
end

class Users
	include DataMapper::Resource
	property :id, Serial
	property :username, Text
	property :password, Text
	property :admin, Boolean
end

DataMapper.finalize.auto_upgrade!
# Set Default Session Variable Values
#session['login'] = false
#session['admin'] = false
#session['username'] = nil

# Resource - books

# Format:   - json

# Create    - POST
# Show      - GET
# Update    - PUT
# Destroy   - DELETE

prefix = "/views"
Dir.foreach(File.join(File.dirname(__FILE__), "views")) do |f|
  full_path = File.join(File.dirname(__FILE__), "views", f)
  unless [".", "..", "admin.html", "customer.html", "login.html", "index.html"].include? f then
    route = prefix + "/" + f
    get route do
      send_file full_path
    end
  end
end

get prefix + '/login.html' do
	if session['login'] == true
		redirect prefix + '/index.html'
	else
		file = File.join(File.dirname(__FILE__), "views", "login.html")
		file = File.open(file)
    return file.read
  end
end

post prefix + '/login.html' do
	@username = params['username-field']
	@password = params['password-field']
	user = Users.first(:username => @username)
	if(user && @password == user['password'])
		# Login Successful
		session['login'] = true
		session['admin'] = user['admin']
		session['name'] = user['username']
		session['error'] = nil
		redirect prefix + '/index.html'
	else
		session['error'] = true
		redirect prefix + '/login.html'
	end
end

get '/did_login_have_error.html' do
	if session['error']
	  file = File.join(File.dirname(__FILE__), "views", "did_login_have_error.html")
	  file = File.open(file)
    return file.read
	end
end

get prefix + '/logout.html' do
	session['login'] = nil
	session['admin'] = nil
	session['name'] = nil
	session['error'] = nil
	redirect prefix + '/login.html'
end

get prefix + '/admin.html' do
	if !session['login']
		redirect prefix + '/login.html'
	elsif !session['admin']
		redirect prefix + '/customer.html'
	else
	  file = File.join(File.dirname(__FILE__), "views", "admin.html")
	  file = File.open(file)
    return file.read
	end
end

get prefix + '/customer.html' do
	if !session['login']
		redirect prefix + '/login.html'
	elsif session['admin']
		redirect prefix + '/admin.html'
	else
	  file = File.join(File.dirname(__FILE__), "views", "customer.html")
	  file = File.open(file)
    return file.read
	end
end

get prefix + '/index.html' do
	if !session['login']
		redirect prefix + '/login.html'
	elsif !session['admin']
		redirect prefix + '/admin.html'
	else
		redirect prefix + '/customer.html'
	end
end

get prefix + '/' do
	redirect prefix + '/index.html'
end

post '/books.json' do
  book = Book.new
  author = Author.new

  info = JSON.parse(params["book"])

  book.title = info["title"]
  book.publisher = info["publisher"]

  author.name = info["author"]

  author.books << book
  book.authors << author

  authorship = Authorship.new
  authorship.book = book
  authorship.author = author
  if authorship.save && book.save && author.save
    return book.to_json
  else
    [500, {"error" => "There was an error!"}.to_json]
  end
end

get '/books.json' do
  puts "Arr, Matey!"
  books = Book.all
  data = []
  for book in books do
    puts book.inspect
    author = book.authors
    puts author.inspect
    for element in author
      if book.customer
        data << Hash["id", book.id, "title", book.title, "publisher", book.publisher, "author", element.name, "checkout", true]
      else
        data << Hash["id", book.id, "title", book.title, "publisher", book.publisher, "author", element.name, "checkout", false]
      end
    end
  end
  puts data.inspect
  #  books = books.to_json
  data = data.to_json
end

get '/book/:id.json' do

end

put '/book/:id.json' do
  book = Book.get(params["id"])
  puts book.inspect
  book.title = params["newcontent"]
  if book.save
    return book.to_json
  else
    [500, {"error" => "There was an error!"}]
  end
end

delete '/book/:id.json' do
  book = Book.get(params["id"])
  if book
    book.destroy
  else
    [500, {"error" => "There was an error!"}]
  end
end

# Resource - customers

# Format:   - json

# Create    - POST
# Show      - GET
# Update    - PUT
# Destroy   - DELETE

post '/customers.json' do
  customer = Customer.new
  newcust = JSON.parse(params["customer"])
  customer.firstname = newcust["firstname"]
  customer.lastname = newcust["lastname"]
  time = Time.now
  customer.registration = "#{time.year}-#{time.month}-#{time.day}"
  if customer.save
    return customer.to_json
  else
    [500, {"error" => "There was an error!"}.to_json]
  end
  
end

get '/customers.json' do
  customers = Customer.all
  for customer in customers do
    puts customer.inspect
  end
  customers = customers.to_json
end

get '/customer/:id.json' do

end

put '/customer/:id.json' do
  customer = Customer.get(params["id"])
  customer.lastname = params["newcontent"]
  if customer.save
    return customer.to_json
  else
    [500, {"error" => "There was an error!"}]
  end
end

delete '/customer/:id.json' do
  customer = Customer.get(params["id"])
  if customer
    customer.destroy
  else
    [500, {"error" => "There was an error!"}]
  end
end

# Resource - checkouts

# Format:   - json

# Create    - POST
# Show      - GET
# Update    - PUT
# Destroy   - DELETE

post '/checkout.json' do
  checkout = Checkout.new
  newcheckout = JSON.parse(params["checkout"])
  puts "newcheckout #{newcheckout.inspect}"
  book = Book.get(newcheckout["book_id"])
  cust = Customer.get(newcheckout["cust_id"])
  checkout.book = book
  checkout.customer = cust
  checkout.current = true
  checkout.returned = false
  time = Time.now
  checkout.checkoutdate = "#{time.year}-#{time.month}-#{time.day}"
  time = time + 14
  checkout.returndate = "#{time.year}-#{time.month}-#{time.day}"
  book.customer = cust
  cust.books << book
  if checkout.save
    return checkout.to_json
  else
    [500, {"error" => "There was an error!"}]
  end
end

get '/checkout.json' do
  @checkouts = Checkout.all
  @checkouts = @checkouts.to_json
end

get '/checkout/book/:id.json' do
  book = Book.get(params["id"])
  cust = book.customer
  data = []
  checkout = Checkout.all(:book => book) & Checkout.all(:customer => cust) & Checkout.all(:current => true)
  puts checkout.inspect
  puts cust.inspect
  puts book.inspect
  if book
      data << Hash["book_title", book.title, "cust_name", "#{cust.firstname} #{cust.lastname}", "publisher", book.publisher, "author", book.authors, "return_date", checkout[0].returndate]
      puts data.inspect
  else
    [500, {"error" => "There was an error!"}]
  end
  data = data.to_json
end

get '/checkout/customer/:id.json' do
  
end

put '/checkout/:id.json' do

end

delete '/checkout/:id.json' do

end




#post '/todos.json' do
#  @todo = Todo.new
#  @newtodo = JSON.parse(params["todo"])
#  @todo.content = @newtodo["content"]
#  @todo.name = @newtodo["name"]
#  @todo.done = @newtodo["done"]
#  
#  if @todo.save
#    return @todo.to_json
#  else
#    [500, {"error" => "There was an error!"}.to_json]
#  end
#end
#
#get '/todos.json' do
#  @todos = Todo.all
#  @todos = @todos.to_json
#end
#
#get '/todo/:id.json' do
#  
#end
#
#put '/todo/:id.json' do
#  
#end
#
#delete '/todo/:id.json' do
#  
#end


