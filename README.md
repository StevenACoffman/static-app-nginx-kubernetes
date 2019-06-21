# static-app-nginx-kubernetes
Containerizing a static application for Kubernetes

## What the heck?

> Single page apps deliver fantastically rich user experiences, and they open up an entirely different avenue for continuous deployment. Separating out a front-end application from the server is a sound strategy for breaking up the responsibilities of the team. Maintaining a separate front-end code base allows teams to iterate on features quickly and interact through formalized contracts in the form of an API.

> Not everything about delivering static assets is so rosy though.
From [Continuously Deploying Single Page Apps](https://blog.codeship.com/continuously-deploying-single-page-apps/)

### Routing in a Single Page Application
If you are build a SPA with react, you probably use `react-router`. There's svelte and angular equivalents.
You should be clear that when we click on an internal link in a static app page, things are a little different
from the traditional web page:
- In a traditional static html web page, the browser will send a request to nginx server for a new html page
  matching that url.
- In react-router, history will listen to the url of the browser, and when it changes,
  it will find the proper component to render, and maybe send async request to ask for data.

For example, when the single page application changes the location to `/users`, there is no static file `/users.html` to serve on nginx.
The browser just changes the url and renders some new component. This works great, until that URL gets bookmarked, reloaded, or shared outside the context of that running application.

In this setup, when a user bookmarks this URL, and restarts the page with the url `/users`, nginx should first try to
find `/users.html`. Of course NGINX fails to find this file, and so it will try to return `index.html`, and let the browser
handle the rest.

### Continuous Integration for a Single Page Application

If you want to perform continuous integration or continuous delivery of a static (single page) application, you need an ephemeral version of it somewhere you can test against.

### Multistage docker builds

An ephemeral, immutable web app container that is optimized for production is great, but the developer needs to have a richer experience without comprimising the fidelity of simulating the production environment. Rex Roof had a genius solution for this.

When building a Dockerfile with multiple build stages, `--target` can be used to specify an intermediate build stage by name as a final stage for the resulting image. Commands after the target stage will be skipped. This way the local development container can be part of the production build pipeline, but each can be tailored for specific needs.

```
FROM node:10.15.0-alpine as development
...
FROM node:10.15.0-alpine as build
...
FROM nginx:1.15.8-alpine as production
...

$ docker build -t development --target development .
$ docker run development
...
$ export GIT_REVISION=$(git rev-parse HEAD)
$ docker build --build-arg GIT_REVISION -t "${REPOSITORY}:${GIT_REVISION}" .
```
Some other nginx configs to look at:
+ https://github.com/h5bp/server-configs-nginx
+ https://github.com/SaraVieira/rick-morty-random-episode/blob/master/nginx.conf
+ https://gist.github.com/huangzhuolin/24f73163e3670b1cd327f2b357fd456a
+ https://gist.github.com/thoop/8165802

## svelte-todomvc

**[svelte-todomvc.surge.sh](http://svelte-todomvc.surge.sh/)**

[TodoMVC](http://todomvc.com/) implemented in [Svelte](https://github.com/sveltejs/svelte). The entire app weighs 3.5kb zipped.

## Where did this content actually come from (useful links):
- https://github.com/SaraVieira/rick-morty-random-episode
- https://github.com/sveltejs/svelte-todomvc
- https://immutablewebapps.org/
- https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-on-centos-7
- https://blog.codeship.com/continuously-deploying-single-page-apps/
- [History api](https://developer.mozilla.org/en-US/docs/Web/API/History_API)
- [Deploy create-react-app with react-router to NGINX](https://gist.github.com/huangzhuolin/24f73163e3670b1cd327f2b357fd456a)
- Rex Roof at Blue Newt made the snazzy multistage docker image
