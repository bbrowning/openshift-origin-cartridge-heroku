app = lambda { |env|
  [200, { "Content-Type" => "text/plain" }, ["Hello from Heroku Buildpacks on OpenShift"]]
}
run app
