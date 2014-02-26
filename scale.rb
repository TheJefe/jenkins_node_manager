#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

HOSTNAME=ENV['JENKINS_HOSTNAME']
PORT=ENV['JENKINS_PORT']
USERNAME=ENV['JENKINS_USERNAME']
API_KEY=ENV['JENKINS_API_KEY']

MIN_NODES=ENV['MIN_NODES'].to_i
MAX_NODES=ENV['MAX_NODES'].to_i

MAIN_URL="http://#{HOSTNAME}:#{PORT}"

NODE_LIST_ENDPOINT = "/computer/api/json" ##endpoint to get a list of nodes
NODE_ADD_ENDPOINT = "/job/Node-add/buildWithParameters?NUM_NODES="
NODE_DELETE_ENDPOINT = "/job/Node-delete/build??delay=0sec"
BUILD_QUEUE_ENDPOINT = "/queue/api/json"

# this method gets data from a specified endpoint and returns it as a string
def http_get(endpoint)
  uri= URI.parse "#{MAIN_URL}#{endpoint}"
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth(USERNAME, API_KEY)
  response = http.request(request)
  response.body
end

# this method will find the first  node name that is currently "offline" and return it.
def find_available_node
  node_name=nil
  nodes = JSON.parse http_get(NODE_LIST_ENDPOINT)
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
  if HOSTNAME == nil || PORT == nil || USERNAME == nil || API_KEY == nil || MIN_NODES <= 0 || MAX_NODES <=0
    raise "environment variables not set. Please check that you have the following set...\
\nJENKINS_HOSTNAME\nJENKINS_PORT\nJENKINS_USERNAME\nJENKINS_API_KEY\nMIN_NODES\nMAX_NODES"
  end

  if ARGV[0] =~ /pretend/
    puts "pretend flag detected"
  end

end

def add_nodes(num)
  puts "adding #{num} nodes"
  num.times do
    http_get("#{NODE_ADD_ENDPOINT}#{num}")
  end
end

def delete_nodes(num)
  puts "deleting #{num} nodes"
  num.times do
    http_get(NODE_DELETE_ENDPOINT)
    sleep 5
  end
end

def scale_nodes()
  node_info   = JSON.parse( http_get(NODE_LIST_ENDPOINT) )
  build_queue = JSON.parse( http_get(BUILD_QUEUE_ENDPOINT) )
  num_queued = build_queue["items"].count
  master_node = node_info["computer"].select {|x| x['displayName'] == "master"}.first
  master_executors = master_node["numExecutors"]
  total_executors = node_info["totalExecutors"] - master_executors
  # ugh, can't get a number of non master busy executors... so we will assume that 
  # the master executors are always busy and do our best
  busy_nodes = node_info["busyExecutors"] - master_executors

  busy_nodes = 0 unless busy_nodes > 0
  difference = total_executors - busy_nodes
  scale_by = 0

  puts "total_executors: #{total_executors}"
  puts "busy_nodes: #{busy_nodes}"
  puts "difference #{difference}"
  puts "queued jobs: #{num_queued}"

  if num_queued > 0
    # don't go over the max count
    scale_by = (total_executors + num_queued) <= MAX_NODES ? num_queued : MAX_NODES - total_executors
  else # scale down, but by how much?
    if (total_executors - difference) >= MIN_NODES
      scale_by = -1 * difference
    else
      scale_by = -1 * ( total_executors - MIN_NODES )
    end
  end

  if scale_by > 0
    puts "scale up by #{scale_by}"
    add_nodes scale_by unless ARGV[0] =~ /pretend/
  else
    puts "scale down by #{ -1 *scale_by}"
    delete_nodes(-1 * scale_by) unless ARGV[0] =~ /pretend/
  end
end

#### MAIN
check_environment
scale_nodes

