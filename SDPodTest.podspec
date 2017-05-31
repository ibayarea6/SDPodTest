
Pod::Spec.new do |s|


  s.name         = "SDPodTest"
  s.version      = "0.0.1"
  s.summary      = "For testing SDPodTest framework."

  s.homepage     = "https://github.com/ibayarea6"

  s.license      = { :type => "MIT", :file => "FILE_LICENSE" }

  s.author             = { "Bommala, Parthasaradhi" => "Parthasaradhi.Bommala@sephora.com" }

  s.platform     = :ios

  s.ios.deployment_target = "10.0"

  s.source       = { :git => "https://github.com/ibayarea6/SDPodTest.git", :tag => "#{s.version}" }

  s.source_files  = "SDPodTest/**/*.{h,m,swift}"

  # s.public_header_files = "Classes/**/*.h"


  s.libraries = "libz.tbd", "libsqlite3.0.tbd"


  #s.dependency "Alamofire", "~> 2.0"

end
