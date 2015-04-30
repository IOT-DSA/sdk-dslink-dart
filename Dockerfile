FROM google/dart
MAINTAINER Kenneth Endfinger <k.endfinger@dglogik.com>

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app
RUN pub get --offline

CMD []
EXPOSE 8080
ENTRYPOINT ["/usr/bin/dart", "bin/broker.dart", "--docker"]
