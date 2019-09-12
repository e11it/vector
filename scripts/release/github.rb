class Github
  URL = 'https://api.github.com'

  def initialize(username: nil, token: nil)
    @username = username || ENV["GITHUB_USERNAME"]
    @token = token || ENV["GITHUB_TOKEN"]
  end

  #
  # Compare
  #

  def compare!(owner_name, repo_name, base, head)
    res = http_client.get("/repos/#{owner_name}/#{repo_name}/compare/#{base}...#{head}")
    res.body
  end

  #
  # Milestones
  #

  def get_milestones!(owner_name, repo_name)
    res = http_client.get("/repos/#{owner_name}/#{repo_name}/milestones")
    res.body
  end

  private
    def http_client
      @http_client ||= Faraday.new(
          url: URL,
          headers: {'Accept' => 'application/vnd.github.symmetra-preview+json'}
        ) do |conn|
          if @username && @token
            conn.request :basic_auth, @username, @token
          end

          conn.request :json

          conn.response :json, :content_type => /\bjson$/

          conn.use Faraday::Response::RaiseError

          conn.adapter Faraday.default_adapter
        end
    end
end