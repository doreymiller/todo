require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"


configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# GET /lists
# GET /lists/new
# POST /lists
# GET /lists/1

# view list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# submit new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# return an error message if the name is invalid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? {|list| list[:name] == name}
    "List name must be unique."
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

get "/lists/new" do
  erb :new_list, layout: :layout
end

get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

post "/lists/:list_id" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# edit an existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# delete todo list
post "/lists/:id/destroy" do
  @list_id = params[:id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo = params[:todo].strip
  error = error_for_todo(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    session[:success] = "Your todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo from the list
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i

  @list = session[:lists][@list_id]
  @list[:todos].delete_at(todo_id)
  session[:success] = "Your todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# update the status of a todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i

  @list = session[:lists][@list_id]
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "Your todo has been updated."
  redirect "/lists/#{@list_id}"
end

# complete all lists
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  session[:lists].each do |list|
    list[:todos].each { |todo| todo[:completed] = true }
  end
  session[:success] = "All your todos have been completed."
  redirect "/lists/#{@list_id}"
end
