# xcBackyard

xcBackyard is lightweight util which save your time for creation Swift Playgrounds with dependencies.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "xcbackyard", :git => "git://github.com/gregoryvit/XCBackyard.git"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem specific_install -l https://github.com/gregoryvit/XCBackyard.git

## Usage

Move to project folder and run

    $ xcbackyard build
    
For remove workspace and clean project, just run

    $ xcbackyard clean

If you want to add playground to project's copy

    $ xcbackyard cp ./TestApp/TestApp.xcodeproj ./TestAppReviewPlayground

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gregoryvit/xcbackyard.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

