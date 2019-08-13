#

set -e
find . -name \*.org -delete
cd docs
jekyll serve
cd ..
