⍝ example.apl -- Demonstrate libseatuya via Dyalog APL FFI
⍝
⍝ Usage:
⍝   )LOAD seatuya
⍝   seatuya.RunExample
⍝
⍝ Or from command line:
⍝   dyalogscript example.apl
⍝
⍝ Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION env vars.

⍝ Load the binding
)COPY seatuya.apl

∇ RunExample;dev_id;local_key;ip;ver;dev;resp
  dev_id←GetEnvOrDefault 'TUYA_DEVICE_ID' '0123456789abcdef01234567'
  local_key←GetEnvOrDefault 'TUYA_LOCAL_KEY' '0123456789abcdef'
  ip←GetEnvOrDefault 'TUYA_IP' '192.168.1.100'
  ver←GetEnvOrDefault 'TUYA_VERSION' '3.4'

  ⍝ Initialize
  seatuya.Init''

  ⎕←'seatuya version: ',⍕seatuya.version

  dev←seatuya.Create dev_id ip local_key ver
  :If dev=0
      ⎕←'ERROR: Could not create device handle'
      :Return
  :EndIf

  ⎕←'Connected: ',(⍕seatuya.IsConnected dev)
  ⎕←'turn_on: ',seatuya.TurnOn dev 1
  ⎕←'status: ',seatuya.Status dev
  ⎕←'turn_off: ',seatuya.TurnOff dev 1

  seatuya.Destroy dev
  ⎕←'Done.'
∇

∇ r←GetEnvOrDefault env default;val
  val←⎕GETENV env
  :If 0=⍴val ⋄ val←default ⋄ :EndIf
  r←val
∇

RunExample
)OFF
