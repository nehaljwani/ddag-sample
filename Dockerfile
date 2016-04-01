FROM            ubuntu
#ENV            HTTP_PROXY      http://proxyuser:proxypwd@proxy.server.com:8080
#ENV            http_proxy      http://proxyuser:proxypwd@proxy.server.com:8080
RUN             apt-get update && apt-get install -y \
                    gcc \
                    make \
                    libpq-dev \
                    cpanminus \
                    postgresql-9.3 \
                    && rm -rf /var/lib/apt/lists/*
RUN             cpanm \
                    JSON \
                    Mojo::Pg \
                    Set::Scalar \
                    Mojo::Redis2 \
                    String::Random \
                    Graph::Directed \
                    Mojolicious::Lite
USER            postgres
RUN             /etc/init.d/postgresql start && \
                psql --command "CREATE USER ddag WITH SUPERUSER PASSWORD 'nlprocks';" && \
                createdb -O ddag pipelines
USER            root
ENTRYPOINT      /etc/init.d/postgresql start && bash
