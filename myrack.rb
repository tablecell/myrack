require "rack"
require "json"
require "sequel"

DB = Sequel.sqlite "jobs.db"
handler = Rack::Handler::WEBrick
  
class Base
  class << self
    def route
      @mime ||= Hash[:ico => "image/x-icon", :js => "text/javascript", :css => "text/css", :json => "application/json"]
      @route ||= Hash["GET" => {}, "POST" => {}]
    end

    def view(tpl)
      filename = "%s.erb" % tpl
      ERB.new(File.read(filename)).result(binding)
    end

    def json(data)
      if data.respond_to?(:to_hash)
        data = data.to_json
      end
    end

    def assets(filename)
      File.open filename, &:read
    end

    def content(content_type)
      arr = content_type.to_a.flatten
      headers = arr[1]
      headers["Content-Type"] = @mime[arr[0].to_sym]
    end

    def GET(path, &block)
      route["GET"][path] = block
    end

    def POST(path, &block)
      route["POST"][path] = block
    end
  end
end

class MyApp < Base

  GET "/" do
    @records = DB[:jobs].all
    view "home"
  end
 
  GET "/new" do
    view "form"
  end

  POST "/new" do |request, headers|
    DB[:jobs].insert request.params
    headers["Location"] = "/"
  end

  GET "/favicon.ico" do |request, headers|
    content "ico" => headers
    assets "favicon.ico"
  end
 
  GET "/spectre.css" do |request, headers|
    content "css" => headers
    assets "spectre.css"
  end

  GET "/api" do |request, headers|
    content "json" => headers
    #json  '{"status":0,"data":"some"}'
    json Hash[:bj => 100]
  end
end

class RackApp
  def call(env)
    dup._call(env)
  end

  def _call(env)
    puts self.object_id
    path = env["PATH_INFO"] ||= "/"
    method = env["REQUEST_METHOD"]
    cb = MyApp.route[method][path]
    headers = {
      "Content-Type" => "text/html",
    }
    if nil == cb
      [404, headers, ["NOT FOUND"]]
    else
      resp = cb.call Rack::Request.new(env), headers
      if headers["Location"]
        [302, headers, ['']]
      else
        [200, headers, [resp]]
      end
    end
  end
end

handler.run RackApp.new
