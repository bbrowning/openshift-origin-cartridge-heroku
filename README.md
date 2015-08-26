# OpenShift Cartridge for Heroku Buildpacks

This cartridge is useful for migrating applications from Heroku to
OpenShift or for developers that are more comfortable with
Heroku-style buildpacks than OpenShift-style cartridges.

To use:

    rhc app create <APP> https://raw.github.com/bbrowning/openshift-origin-cartridge-heroku/master/metadata/manifest.yml

For now only a preselected set of heroku buildpacks - clojure, go,
gradle, grails, java, multi, nodejs, php, play, python, ruby, and
scala - will work. The buildpack to use will be auto-detected using
Heroku's detection logic based on your application's source code. We
only run the web Procfile entry.

Things are still very early, so expect bugs.
