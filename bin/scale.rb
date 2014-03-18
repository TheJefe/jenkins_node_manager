#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require '../lib/jenkins.rb'

MIN_NODES=ENV['MIN_NODES'].to_i
MAX_NODES=ENV['MAX_NODES'].to_i

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

def scale_nodes()
  node_info   = JSON.parse( Jenkins.http_get(NODE_LIST_ENDPOINT) )
  build_queue = JSON.parse( Jenkins.http_get(BUILD_QUEUE_ENDPOINT) )
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

  if num_queued > 0 and num_queued > difference
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
    Jenkins.add_nodes scale_by unless ARGV[0] =~ /pretend/
  else
    puts "scale down by #{ -1 *scale_by}"
    Jenkins.delete_nodes(-1 * scale_by) unless ARGV[0] =~ /pretend/
  end
end

#### MAIN
check_environment
scale_nodes

