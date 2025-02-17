server '104.131.172.91', roles: [:web, :app, :db], primary: true
set :stage,  :production
set :branch, '3.14'
