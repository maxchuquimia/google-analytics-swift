# Google Analytics - Swift
RESTful interface for the Google Analytics Measurment Protocol. In Swift. 

## Motivation
Last night two things happened: my girlfriend made last minute dinner plans and I reached a new level of frustration with the analytics provider I integrated with for my recently released Cocoa app (there is no official  Google Analytics SDK for macOS). 

Anyway, long story short, instead of going to bed early I made this wrapper for the Google Measurement API. 

## Support
You can theoretically use this in your Mac or iOS apps, or anywhere that runs Swift. I haven’t tested it everywhere though, so feel free to submit PRs. 

This entire codebase is a single file, so I don’t see the need to add it to Cocoapods etc.  Drop the file into your XCode project, use a git submodule... it’s up to you to decide what’s best. 

## Usage
Set up the tracker with default values for every request:

```
GAMeasurement.setup(...)
```


Then, start tracking as needed:

```
GAMeasurement.track(.event(...))
```

It’s as strongly typed as possible, so everything should be fairly self explanatory.
