⍝ example.apl — demonstrate libseatuya via Dyalog APL

deviceId←{6::'0123456789abcdef01234567' ⋄ ⊃2⎕NQ'.' 'GetEnvironment' 'TUYA_DEVICE_ID'}⍬
localKey←{6::'0123456789abcdef' ⋄ ⊃2⎕NQ'.' 'GetEnvironment' 'TUYA_LOCAL_KEY'}⍬
ip←{6::'192.168.1.100' ⋄ ⊃2⎕NQ'.' 'GetEnvironment' 'TUYA_IP'}⍬
ver←{6::'3.4' ⋄ ⊃2⎕NQ'.' 'GetEnvironment' 'TUYA_VERSION'}⍬

⎕←'seatuya version: ',⍕seatuya.version

dev←seatuya.create deviceId ip localKey ver
:If dev=0
    ⎕←'ERROR: Could not create device handle' ⋄ →0
:EndIf

⎕←'Connected: ',⍕dev seatuya.isConnected
⎕←'turn_on: ',⍕dev seatuya.turnOn 1
⎕←'status: ',⍕dev seatuya.status
⎕←'turn_off: ',⍕dev seatuya.turnOff 1

seatuya.destroy dev
⎕←'Done.'
