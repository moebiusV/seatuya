⍝ seatuya.apl — Dyalog APL FFI bindings for libseatuya
⍝
⍝ Dyalog APL binding using ⎕NA (Name Association) for C interop.
⍝ The ⎕NA system function declares a C function and returns a
⍝ namespace of monadic/dyadic derived functions.
⍝
⍝ Usage:
⍝   ⎕←seatuya.version
⍝   dev←seatuya.create deviceId ip localKey '3.4'
⍝   ⎕←dev seatuya.turnOn 1
⍝   seatuya.destroy dev

:Namespace seatuya
    ⎕IO←0

    ⍝ Library path
    lib←{6::'libseatuya.so' ⋄ ⊃⎕SH'echo $SEATUYA_LIB'}⍬

    ⍝ Function declarations
    version←{lib ⎕NA'I4 tuya_version'}⍬

    create←{ ⍝ did addr key ver → handle
        did addr key ver lib ⎕NA'I4 tuya_create <0T1 <0T1 <0T1 <0T1'
        ⍵
    }⍬

    destroy←{lib ⎕NA' tuya_destroy I4' ⋄ 'tuya_destroy'⎕NA'void tuya_destroy(void*)'⊣⍵}⍬

    connect←{dev host←⍵ ⋄ dev host lib ⎕NA'I4 tuya_connect I4 <0T1'}

    isConnected←{dev←⍵ ⋄ dev lib ⎕NA'I4 tuya_is_connected I4'}

    turnOn←{dev dp←⍵ ⋄ dev dp lib ⎕NA'<0T1 tuya_turn_on I4 I4'}

    turnOff←{dev dp←⍵ ⋄ dev dp lib ⎕NA'<0T1 tuya_turn_off I4 I4'}

    status←{dev←⍵ ⋄ dev lib ⎕NA'<0T1 tuya_status I4'}

    heartbeat←{dev←⍵ ⋄ dev lib ⎕NA'<0T1 tuya_heartbeat I4'}

    setValueBool←{dev dp val←⍵ ⋄ dev dp val lib ⎕NA'<0T1 tuya_set_value_bool I4 I4 I4'}

    setValueInt←{dev dp val←⍵ ⋄ dev dp val lib ⎕NA'<0T1 tuya_set_value_int I4 I4 I4'}

    setValueFloat←{dev dp val←⍵ ⋄ dev dp val lib ⎕NA'<0T1 tuya_set_value_float I4 I4 F8'}

    setDevice22←{dev json←⍵ ⋄ dev json lib ⎕NA' tuya_set_device22 I4 <0T1'}

    freeString←{ptr←⍵ ⋄ ptr lib ⎕NA' tuya_free_string <0T1'}

    ⍝ Constants
    CMD_CONTROL←7 ⋄ CMD_DP_QUERY←10 ⋄ CMD_HEART_BEAT←9
    CMD_STATUS←8 ⋄ CMD_CONTROL_NEW←13 ⋄ CMD_DP_QUERY_NEW←16
    DEFAULT_PORT←6668 ⋄ BUFSIZE←1024

    ⍝ Type-dispatched setter
    setValue←{ ⍝ dev dp value → result
        dev dp val←⍵
        :If 0=1↑0⍴val          ⍝ numeric
            :If val=⌊val ⋄ dev dp val setValueInt
            :Else ⋄ dev dp val setValueFloat
            :EndIf
        :Else ⋄ dev dp val setValueString
        :EndIf
    }
:EndNamespace
