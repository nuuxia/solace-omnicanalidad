server '159.203.161.226', roles: [:web, :app, :db], primary: true
set :stage,  :production
set :branch, 'hiding_all_conversations_for_agents'
