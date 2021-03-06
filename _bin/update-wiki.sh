#!/bin/bash -e
cd "`dirname "$0"`/.."
mkdir -p 'wiki'

echo 'Retrieving the wiki page lists ..'
curl -s https://github.com/netty/netty/wiki/_pages | grep -E '<a href="/netty/netty/wiki(/[A-Z][-\._A-Za-z0-9]+)?">[^<]+</a>' > 'wiki/_pages'

echo The wiki contains `wc -l 'wiki/_pages'` pages.

{
  echo '---'
  echo 'layout: base'
  echo "title: 'All documents'"
  echo '---'
  echo
  echo '%h1 All documentation pages'
  echo
  echo '%ul'
} > 'wiki/all-documents.html.haml'

cat 'wiki/_pages' | while read -r LINE; do
  if [[ ${LINE} =~ (/netty/netty/wiki(/([A-Z][-\._A-Za-z0-9]+))?)\"\>([^\<]+) ]]; then
    WIKI_URI=${BASH_REMATCH[1]}
    WIKI_FILE=${BASH_REMATCH[3]}
    WIKI_GITHUB_NAME="$WIKI_FILE"
    if [[ "x$WIKI_FILE" = 'x' ]]; then
      WIKI_FILE='index'
      WIKI_GITHUB_NAME='Home'
    else
      WIKI_FILE=`echo "$WIKI_FILE" | tr '[:upper:]' '[:lower:]'`
    fi
    WIKI_TITLE=${BASH_REMATCH[4]}
    echo Retrieving: "$WIKI_FILE" from "$WIKI_URI" ..
    {
      echo '---'
      echo 'layout: wiki'
      echo "title: '$WIKI_TITLE'"
      echo "github_name: '$WIKI_GITHUB_NAME'"
      echo "retrieval_date: '`date '+%d-%b-%Y'`'"
      echo '---'
      echo
      echo ':plain'
      {
        echo '# encoding: UTF-8'
        echo "require 'nokogiri'"
        echo "require 'htmlentities'"
        echo '@doc = Nokogiri::HTML::DocumentFragment.parse <<-EOF_92ca82985abd11f6a579fe9b19b578020e0d454d'
        curl -s "https://github.com$WIKI_URI" || exit 1
        echo
        echo 'EOF_92ca82985abd11f6a579fe9b19b578020e0d454d'

        # Generate TOC
        echo '
          headings = @doc.css("h2,h3,h4")
          if headings.size() > 1
            coder = HTMLEntities.new
            toc_idx = 0
            toc_level = 2
            first = true
            puts "<div class=\"wiki-toc well pull-right\">"
            puts "<ul class=\"nav nav-list\">"
            puts "<li class=\"nav-header\">Table of Contents"
            for h in headings
              section_id = "wiki-" + h.name + "-" + toc_idx.to_s
              toc_idx = toc_idx + 1
              h["id"] = section_id
              new_toc_level = h.name[1].ord - 48
              toc_text = coder.encode(h.inner_text)
              if new_toc_level == toc_level
                puts "</li><li><a href=\"#" + section_id + "\" title=\"" + toc_text + "\">" + toc_text + "</a>"
                first = false
              elsif new_toc_level == toc_level + 1
                if first # first heading is not h2 but h3
                  puts "</li><li>"
                end
                toc_level = new_toc_level
                puts "<ul class=\"nav nav-list\"><li><a href=\"#" + section_id + "\" title=\"" + toc_text + "\">" + toc_text + "</a>"
                first = false;
              elsif !first and new_toc_level == toc_level - 1
                toc_level = new_toc_level
                puts "</li></ul></li><li><a href=\"#" + section_id + "\" title=\"" + toc_text + "\">" + toc_text + "</a>"
                first = false;
              end
            end
            while toc_level >= 2
              toc_level = toc_level - 1
              puts "</li></ul>"
            end
            puts "</div>"
          end
        '

        echo 'print @doc.at_css "div#wiki-body"'
        # Perl regex soup below:
        # 1. DOS to UNIX
        # 2. Indentation
        # 3. Remove broken links
        # 4. Make internal links to wiki home work
        # 5. Make internal links to other wiki pages work
        # 6. Escape backslash
        # 7. Escape single-quote
      } | ruby \
        | perl -pi0 -e 's/[\r]//g' \
        | perl -pi -e 's/^/  /g' \
        | perl -pi -e 's/<a [^>]*absent[^>]*>(((?!<\/a>).)*)<\/a>/<span class="broken-link">$1<\/span>/gi' \
        | perl -pi -e 's#/netty/netty/wiki/(Home)?"#index.html"#gi' \
        | perl -pi -e 's#/netty/netty/wiki/([^"]+)#\L$1.html#g' \
        || exit 1
      echo
    } > "wiki/$WIKI_FILE.html.haml"

    {
      echo '  %li'
      echo "    %a{ :href=>'$WIKI_FILE.html' } $WIKI_TITLE"
    } >> 'wiki/all-documents.html.haml'
  fi
done

{
  echo
  echo '.text-right'
  echo "  %small Last retrived on `date '+%d-%b-%Y'`"
  echo
} >> 'wiki/all-documents.html.haml'

