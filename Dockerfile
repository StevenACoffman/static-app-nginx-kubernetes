# container for development
FROM node:10.15.0-alpine as development

RUN apk add --update gettext libintl \
 && cp /usr/bin/envsubst /usr/local/bin/envsubst \
 && apk del gettext

# RUN yarn global add yarn
WORKDIR /app
ENV HOME /app

ADD entrypoint.sh /
run chmod 755 /entrypoint.sh
ADD package-lock.json package.json rollup.config.js /app/
# ADD .yarnrc yarn.lock package.json /app/

# yarn install timeouts still result in sucessful error code
# RUN yarn install \
#   && if [ ! -d node_modules ] ; then \
#        echo "===> yarn install failed, check VPN"; \
#        exit 1; \
#     fi
RUN npm install
COPY public/ /app/public/
COPY src/ /app/src/

EXPOSE 3000

# the entrypoint runs all commands.   this gets called as /entrypoint.sh $CMD
# this entrypoint script does our config.js templating
ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm","start"]

# temp build container
FROM node:10.15.0-alpine as build
COPY --from=development /app /app
WORKDIR /app
RUN npm run build

# production container
FROM nginx:1.15.8-alpine as production

COPY --from=build /app/public /var/www
COPY --from=development /usr/local/bin/envsubst /usr/local/bin

ADD nginx.conf /etc/nginx/nginx.conf

ADD entrypoint.sh /
RUN chmod 755 /entrypoint.sh
RUN touch /etc/nginx/conf.d/default.conf /var/run/nginx.pid \
  && chown nginx /etc/nginx/conf.d/default.conf /var/run/nginx.pid

# always put these as low as possible, but before any USER setting
ARG GIT_REVISION=unknown
LABEL git-commit=$GIT_REVISION
RUN echo $GIT_REVISION > /version.txt

# WORKDIR /app
USER nginx
ENV PORT 8080
EXPOSE $PORT

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx","-g","daemon off;"]
