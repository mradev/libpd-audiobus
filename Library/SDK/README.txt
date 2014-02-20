Audiobus SDK -- Version 1.0.2.5 -- Nov 19 2013
==============================================

Thanks for downloading the Audiobus distribution!

See http://developer.audiob.us/doc/ for the developer documentation,
and see the Samples folder for a number of sample projects.

If you have any questions, please don't hesitate to join us on 
the developer community forum at http://heroes.audiob.us.

Cheers!

Audiobus Team
http://audiob.us

Changes
=======

1.0.2.5
-------

  - Fixed iOS 5 compatibility

1.0.2.4
-------

  - Addressed an occasional crash when system comm resources cleaned up (e.g.
    on screen lock, etc.)

1.0.2.3
-------

  - 64-bit support

1.0.2.2
-------

  - Added support for retrieving icon via asset catalog
  - Addressed an ABAudiobusAudioUnitWrapper 'insz' audio error

1.0.2.1
-------

  - Exposed property 'muteLiveAudioInputWhenConnectedToSelf' on ABInputPort,
    to enable live audio input when the input port detects an output port from
    the same app is connected.
  - Exposed property 'connectedToSelf' on ABInputPort to determine when there
    is a feedback component in the signal.

1.0.2
-----

  - Support for animated triggers
  - Performance improvements for connection panel updates
  - Fixed an issue on iOS 7 where remote versions of apps, on other devices,
    interfere with the operation of local apps.
  - Implemented per-source volume/pan controls for ABMultiStreamBuffer
  - Refined Connection Panel drag gesture to avoid some false positives

1.0.1.5
-------

  - Fixed a problem where ABFilterPortGetOutput didn't correctly silence
    the provided buffer when silent output should be provided.
  - Report YES for ABFilterPortIsConnected if either input OR output of
    filter is connected.

1.0.1.4
-------

  - Addressed potential rare crash upon receiver disconnection.

1.0.1.3
-------

  - Improved assertion reporting
  - Added missing frameworks to sample apps

1.0.1.2
-------

  - Addressed a crash when Audiobus is unable to be used due to underlying 
    system problems.

1.0.1.1
-------

  - Use Security framework. Note: You will need to add Security.framework to your 
    build.

1.0.1
-----

New features:

  - Added ABMultiStreamBuffer class, for synchronising multiple
    streams outside of Audiobus - particularly useful when implementing
    multi-stream receiver apps.
  - Implemented per-stream live buffer dequeuing for ABLiveBuffer, with
    ABLiveBufferDequeueSingleSource (see documentation for important details).
  - Added ability to change audio unit used with ABAudiobusAudioUnitWrapper.
  - Added per source volume/pan settings for ABLiveBuffer
  - Added ability to change the audio format for many utility classes.
  - Automatically sort triggers in order Rewind, Play, Record
  - Implemented API key system. Please read [revised documentation](
    http://developer.audiob.us/doc/_integration-_guide.html#Register-App)
  - Added "AB Torture Test" sample app.
  - Added a new "AB Multitrack Receiver" sample, replacing the now renamed
    "AB Multitrack Oscilloscope" sample.
  - Added "Monitor" mode switch to "AB Receiver" sample app for testing
    correct implementation of output muting for sender apps.
    
Fixes:
 
  - Recover from Bonjour name clashes.
  - Fixed a crash that occurs on devices with particularly long device names,
    or reasonably long device names in non-ASCII character sets.
  - Fixed problem with sending messages to suspended/terminated apps causing a
    long delay.
  - Added a workaround to an inflexibility in Apple's audio converter system.
  - Increased peer timeout (Bonjour service interruption workaround) to 4 seconds.
  - Tweaked a view stuttering issue when changing orientation and simultaneously
    changing the connection panel position (ABAudiobusConnectionPanelPosition).
  - Fixed an ABLiveBuffer stall issue
  - Fixed a problem with wrapper letting mic audio through when not getting audio
  - Renamed 'sessionPeers' property of ABAudiobusController to 'connectedPeers'
  - Revised 'connectedPorts' property (now NSArray, not NSSet) to encompass all
    connected ports of the current session, not just the ones directly connected 
    to the app.
  - Fixed an issue with ABLiveBuffer when switching an input stream to a 
    different timeline (e.g. moving between Remote IO input and Audiobus audio).
  - Fixed a logic error in the mixer/syncer unit.
  - Addressed scenario where an input port is connected to an output port
    of the same app (when allowsMultipleInstancesInConnectionGraph is set):
    ABInputPortReceiveLive will now return silence if this is the case, and the
    ABInputPortAttributePlaysLiveAudio flag, if set on the input port, 
    will be hidden from the output port in order to prevent output muting
    entirely.
  - Added a second wait after peer disappearance to actually report peer as
    absent, to work around a Bonjour service glitch.
  - Fixed a bug with parsing display name from peer metadata
  - Addressed an issue with misconfigured wireless networks.
  - Improvements to error concealing code and audio receiver.
  - Various bug fixes for issues in the presence of certain audio format
    environments; particularly, formats with > 2 channels.
  - No longer call ABFilterPort's process block if no destination is
    connected.
  - Fixed spurious scrolling in connection panel.

1.0
---

  - Initial public release