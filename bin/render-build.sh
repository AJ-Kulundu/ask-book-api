# exit on error
set -o errexit

bundle install
bundle exec rails db:migrate