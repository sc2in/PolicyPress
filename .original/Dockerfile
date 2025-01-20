FROM jetpackio/devbox-root-user:latest

# Installing your devbox project
WORKDIR /work
COPY devbox.json devbox.json
COPY devbox.lock devbox.lock

RUN devbox run -- echo "Installed Packages."
ENV PUBLISH=0

CMD ["devbox", "run", "--", "ci"]
