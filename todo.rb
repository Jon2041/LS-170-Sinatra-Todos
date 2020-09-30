require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def count_remaining_todos(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def get_progess_nums(list)
    "#{count_remaining_todos(list)} / #{list[:todos].size}"
  end

  def not_empty?(list)
    list[:todos].size > 0
  end

  def completed?(list)
    not_empty?(list) && count_remaining_todos(list).zero?
  end

  def list_class(list)
    "complete" if completed?(list)
  end

  def reorder_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}

    lists.each_with_index do |list, ind|
      completed?(list) ? complete_lists[list] = ind : incomplete_lists[list] = ind
    end

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def reorder_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, ind|
      todo[:completed] ? complete_todos[todo] = ind : incomplete_todos[todo] = ind
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

get "/" do
  redirect "/lists"
end

# GET  /lists       -> view all lists
# GET  /lists/new   -> new list form
# POST /lists       -> create new list
# GET  /lists/1     -> view a single list

# View of all the lists.
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Renders the new list form.
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def list_name_error(name)
  if !(1..100).cover? name.size
    "List names must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List names must be unique."
  end
end

# Creates a new list.
post "/lists" do
  list_name = params[:list_name].strip

  error = list_name_error(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list was successfully created!"
    redirect "/lists"
  end
end

# Validate a list index
def valid_index?(index)
  max_index = session[:lists].size
  (0...max_index).cover? index
end

# Display a single list and its contents.
get "/lists/:num" do
  @index = params[:num].to_i
  if valid_index?(@index)
    @list = session[:lists][@index]
    erb :single_list, layout: :layout
  else
    session[:error] = "That list could not be found."
    redirect "/lists"
  end
end

# Renders an edit form
get "/lists/:num/edit" do
  @index = params[:num].to_i
  @list = session[:lists][@index]

  erb :edit_list, layout: :layout
end

# Edits a list name
post "/lists/:num" do
  index = params[:num].to_i
  @list = session[:lists][index]

  new_name = params[:list_name].strip
  error = list_name_error(new_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @list[:name] = new_name
    session[:success] = "The list name was successfully changed!"
    redirect "/lists/#{index}"
  end
end

# Delete a list
post "/lists/:num/delete" do
  session[:lists].delete_at(params[:num].to_i)
  session[:success] = "The list was successfully deleted."
  redirect "/lists"
end

# Validate todo text
def todo_error(text, index)
  if !(1..200).cover?(text.size)
    "Todos must be between 1 and 200 characters."
  end
end

# Add a todo to the list
post "/lists/:num/todos" do
  @index = params[:num].to_i
  @list = session[:lists][@index]
  todo = { name: params[:todo], completed: false }

  error = todo_error(todo[:name], @index)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    @list[:todos] << todo
    session[:success] = "A new todo was added!"
    redirect "/lists/#{@index}"
  end
end

# Marks all todos complete
post "/lists/:num/todos/complete" do
  list_id = params[:num].to_i

  session[:lists][list_id][:todos].each do |todo|
    todo[:completed] = "true"
  end

  session[:success] = "All todos marked complete!"
  redirect "/lists/#{list_id}"
end

# Delete a todo from the list
post "/lists/:num/todos/:todo_num/delete" do
  list_id = params[:num].to_i
  todo_id = params[:todo_num].to_i
  @list = session[:lists][list_id]
  @list[:todos].delete_at(todo_id)

  redirect "/lists/#{list_id}"
end

# Toggle a todo completion status
post "/lists/:num/todos/:todo_num" do
  list_id = params[:num].to_i
  todo_id = params[:todo_num].to_i
  @list = session[:lists][list_id]
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "This todo has been updated."
  redirect "/lists/#{list_id}"
end
