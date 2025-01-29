server '159.203.161.226', roles: [:web, :app, :db], primary: true
set :stage,  :production
set :branch, 'new_conversation_report'
