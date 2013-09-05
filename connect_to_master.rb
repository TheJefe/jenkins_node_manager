require 'net/http'
require 'json'
require 'uri'
require 'open-uri'
require 'rexml/document'
require 'timeout'


#These are environment variables that are used to connect to masters API
@hostname=ENV['JENKINS_HOSTNAME']
@port=ENV['JENKINS_PORT']
@username=ENV['JENKINS_USERNAME']
@api_key=ENV['JENKINS_API_KEY']

@main_url="http://#{@hostname}:#{@port}"
@node_list_end_point= "/computer/api/json" ##endpoint to get a list of nodes

# Checks that the necessary environment variables are set
def check_environment
        if @hostname == nil || @port == nil || @username == nil || @api_key == nil
                raise "environment variables not set. Please check that you have the following set...\nJENKINS_HOSTNAME\nJENKINS_PORT\nJENKINS_USERNAME\nJENKINS_API_KEY"
        end
end

# this method gets data from a specified endpoint and returns it as a string
def http_get(end_point)
        uri= URI.parse "#{@main_url}#{end_point}"
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(@username, @api_key)
        response = http.request(request)
        response.body
end

def download_client_jar
        puts "downloading slave.jar..."
        open('slave.jar', 'wb') do |file|
                file << open("#{@main_url}/jnlpJars/slave.jar").read
        end
        puts "download complete"
end

# this method is used to get the secret key for a node on the master so that it can authenticate
def get_secret(node_name)
        puts "downloading slave-agent.jnlp..."
        jnlp= http_get("/computer/#{node_name}/slave-agent.jnlp")
        doc = REXML::Document.new(jnlp)
        doc.get_text('jnlp/application-desc/argument')
end

# this method will find the first  node name that is currently "offline" and return it.
def find_available_node
        node_name=nil
        nodes = JSON.parse http_get(@node_list_end_point)
        nodes["computer"].each do |i|
                if i["offline"]
                        node_name=i["displayName"]
                        break
                end
        end

        return node_name
end

#### MAIN ####

check_environment
download_client_jar

## this will attempt to connect 5 times before giving up
for i in 1..5
        node_name=find_available_node

        if node_name.nil? || !defined? node_name
                raise "no offline nodes found. goto #{@main_url} to create a new one"
        end

        puts "found available slot: #{node_name}"

        secret = get_secret(node_name)

        cmd = "java -jar slave.jar -jnlpUrl #{@main_url}/computer/#{node_name}/slave-agent.jnlp -secret #{secret} &"
        puts "starting jar file with: \n #{cmd}"
        fork{`#{cmd}`}
        # If the process does not return within 10 seconds, we assume that it has connected, otherwise we look for another node name and try again
        begin
                Timeout.timeout(10) do 
                        Process.wait
                end
        rescue Timeout::Error
                puts "Connection appears to have been successful"
                exit 0
        end
        sleep 2
        pid = $?.pid
        result = `ps -p #{pid}; echo $?`.split("\n")[1]

        puts "results #{result}"
        if result.to_i == 0
                puts "connected to master successfully"
                exit 0
        else
                puts "failed #{i} times"
        end
end
