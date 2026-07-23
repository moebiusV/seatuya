"example.st — demonstrate libseatuya via Squeak Smalltalk FFI

 Run in Squeak:
   FileStream fileIn: 'seatuya.st'.
   FileStream fileIn: 'example.st'.
   SeatuyaExample run.
"

Object subclass: #SeatuyaExample
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Seatuya-Examples'

SeatuyaExample class >> run
    | deviceId localKey ip ver dev |
    deviceId := (Smalltalk os environment at: 'TUYA_DEVICE_ID' ifAbsent: nil)
        ifNil: [ '0123456789abcdef01234567' ].
    localKey := (Smalltalk os environment at: 'TUYA_LOCAL_KEY' ifAbsent: nil)
        ifNil: [ '0123456789abcdef' ].
    ip := (Smalltalk os environment at: 'TUYA_IP' ifAbsent: nil)
        ifNil: [ '192.168.1.100' ].
    ver := (Smalltalk os environment at: 'TUYA_VERSION' ifAbsent: nil)
        ifNil: [ '3.4' ].

    Transcript show: 'seatuya version: ', SeatuyaLibrary tuyaVersion; cr.

    dev := SeatuyaDevice create: deviceId address: ip localKey: localKey version: ver.
    dev isNil ifTrue: [
        Transcript show: 'ERROR: Could not create device handle'; cr.
        ^ self ].

    Transcript show: 'Connected: ', dev isConnected printString; cr.
    Transcript show: 'turn_on: ', (dev turnOn: 1); cr.
    Transcript show: 'status: ', dev status; cr.
    Transcript show: 'turn_off: ', (dev turnOff: 1); cr.
    dev destroy.
    Transcript show: 'Done.'; cr.
