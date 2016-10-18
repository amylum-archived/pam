FROM dock0/pkgforge
RUN pacman -S --needed --noconfirm libxml2 w3m docbook-xml docbook-xsl
