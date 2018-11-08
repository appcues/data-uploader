require "./lib/appcues_data_uploader/version"

Gem::Specification.new do |s|
  s.name     = 'appcues_data_uploader'
  s.version  = AppcuesDataUploader::VERSION
  s.date     = AppcuesDataUploader::VERSION_DATE
  s.summary  = 'Upload CSVs of user profile data to the Appcues API'
  s.homepage = 'https://github.com/appcues/data-uploader'
  s.authors  = ['pete gamache']
  s.email    = 'pete@gamache.org'
  s.license  = 'MIT'
  s.has_rdoc = false
  s.files    = Dir['lib/**/*'] + Dir['bin/**/*']
  s.require_path = 'lib'
  s.bindir   = 'bin'
  s.executables << 'appcues-data-uploader'
  s.required_ruby_version = '>= 2.0'
end
