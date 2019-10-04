#

set -e
find . -name \*.org -delete
wname "jekyll"
bundle exec jekyll serve
