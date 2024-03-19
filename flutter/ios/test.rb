require 'yaml'

pubspec = YAML.load_file('./../pubspec.yaml')
version = pubspec['version']

puts version
