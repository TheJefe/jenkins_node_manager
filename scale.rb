require 'net/http'
require 'json'
require 'uri'

@hostname=ENV['JENKINS_HOSTNAME']
@port=ENV['JENKINS_PORT']
@username=ENV['JENKINS_USERNAME']
@api_key=ENV['JENKINS_API_KEY']

@MIN_COMPUTERS=9 #one blank one for master and another for the template node
@MAX_COMPUTERS=20

@main_url="http://#{@hostname}:#{@port}"

@node_list_endpoint = "/computer/api/json" ##endpoint to get a list of nodes
@node_add_endpoint = "/job/Node-add/buildWithParameters?NUM_NODES="
@node_delete_endpoint = "/job/Node-delete/build??delay=0sec"
@build_queue_endpoint = "/queue/api/json"

# this method gets data from a specified endpoint and returns it as a string
def http_get(endpoint)
        uri= URI.parse "#{@main_url}#{endpoint}"
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(@username, @api_key)
        response = http.request(request)
        response.body
end

# this method will find the first  node name that is currently "offline" and return it.
def find_available_node
        node_name=nil
        nodes = JSON.parse http_get(@node_list_endpoint)
        nodes["computer"].each do |i|
                if i["offline"]
                        node_name=i["displayName"]
                        break
                end
        end

        return node_name
end

# checks to make sure the required environment variables are set
def check_environment
        if @hostname == nil || @port == nil || @username == nil || @api_key == nil
                raise "environment variables not set. Please check that you have the following set...\nJENKINS_HOSTNAME\nJENKINS_PORT\nJENKINS_USERNAME\nJENKINS_API_KEY"
        end
end

def count_executors(json)
        num = 0
        json["computer"].each do |computer|
                num += computer["numExecutors"]
        end
      return num
end

def add_nodes(num)
                puts "adding #{num} nodes"
        num.times do
                http_get("#{@node_add_endpoint}#{num}")
        end
end

def delete_nodes(num)
                puts "deleting #{num} nodes"
        num.times do
                http_get(@node_delete_endpoint)
                sleep 5
        end
end

def scale_nodes()
        node_info   = JSON.parse( http_get(@node_list_endpoint) )
        build_queue = JSON.parse( http_get(@build_queue_endpoint) )
        num_queued = build_queue["items"].count
        total_executors = count_executors(node_info)
        busy_nodes = node_info["busyExecutors"]
        difference = total_executors - busy_nodes
        scale_by = 0

        puts "total_executors: #{total_executors}"
        puts "busy_nodes: #{busy_nodes}"
        puts "difference #{difference}"
        puts "queued jobs: #{num_queued}"

        if num_queued > 0
                # don't go over the max count
                scale_by = (total_executors + num_queued) <= @MAX_COMPUTERS ? num_queued : @MAX_COMPUTERS - total_executors
        else
                if ( (total_executors - difference) >= @MIN_COMPUTERS )
                        scale_by = -1 * difference
                else
                        scale_by = -1 * ( total_executors - @MIN_COMPUTERS)
                end

        end

        if scale_by > 0
                add_nodes scale_by
        else
                delete_nodes(-1 * scale_by)
        end
end

#### MAIN ####

check_environment
scale_nodes()

