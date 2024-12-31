module TikTok
  class Client
    include HTTParty
    base_uri TIK_TOK[:base_url]

    def initialize(access_token)
      @access_token = access_token
    end

    def fetch_new_messages(notification)
      response = self.class.get("/messages/#{notification["resource"]}", headers: headers, query: { tag: 'post_sale' })
      handle_response(response)
    end
  end
end
