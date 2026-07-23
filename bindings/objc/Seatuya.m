// Seatuya.m — Objective-C implementation for libseatuya

#import "Seatuya.h"

static NSString *_Nullable _consume(char *_Nullable ptr) {
    if (!ptr) return nil;
    NSString *s = [NSString stringWithUTF8String:ptr];
    tuya_free_string(ptr);
    return s;
}

@implementation SeatuyaDevice

@synthesize handle = _handle;

+ (NSString *)version {
    return [NSString stringWithUTF8String:tuya_version()];
}

- (instancetype)initWithDeviceId:(NSString *)deviceId
                         address:(NSString *)address
                        localKey:(NSString *)localKey
                         version:(NSString *)version {
    self = [super init];
    if (self) {
        _handle = tuya_create(deviceId.UTF8String, address.UTF8String,
                              localKey.UTF8String, version.UTF8String);
        if (!_handle) return nil;
    }
    return self;
}

- (instancetype)initWithVersion:(NSString *)version {
    self = [super init];
    if (self) {
        _handle = tuya_alloc(version.UTF8String);
        if (!_handle) return nil;
    }
    return self;
}

- (void)dealloc {
    if (_handle) { tuya_destroy(_handle); _handle = NULL; }
}

- (void)setCredentialsWithDeviceId:(NSString *)deviceId localKey:(NSString *)localKey {
    tuya_set_credentials(_handle, deviceId.UTF8String, localKey.UTF8String);
}

- (NSString *)deviceId { return [NSString stringWithUTF8String:tuya_get_device_id(_handle)]; }
- (NSString *)localKey { return [NSString stringWithUTF8String:tuya_get_local_key(_handle)]; }
- (NSString *)ip       { return [NSString stringWithUTF8String:tuya_get_ip(_handle)]; }

- (BOOL)connect:(NSString *)hostname { return tuya_connect(_handle, hostname.UTF8String); }
- (void)disconnect { tuya_disconnect(_handle); }
- (BOOL)isConnected { return tuya_is_connected(_handle); }
- (BOOL)reconnect   { return tuya_reconnect(_handle); }

- (void)setRetryLimit:(int)limit { tuya_set_retry_limit(_handle, limit); }
- (void)setRetryDelay:(int)ms    { tuya_set_retry_delay(_handle, ms); }
- (int)retryLimit  { return tuya_get_retry_limit(_handle); }
- (int)retryDelay  { return tuya_get_retry_delay(_handle); }

- (BOOL)negotiateSession:(NSString *)key { return tuya_negotiate_session(_handle, key.UTF8String); }

- (int)protocolVersion { return tuya_get_protocol(_handle); }
- (int)sessionState    { return tuya_get_session_state(_handle); }
- (int)socketState     { return tuya_get_socket_state(_handle); }
- (int)lastError       { return tuya_get_last_error(_handle); }

- (void)setAsyncMode:(BOOL)flag { tuya_set_async_mode(_handle, flag); }

- (NSString *)setValueBool:(BOOL)value forDP:(int)dp {
    return _consume(tuya_set_value_bool(_handle, dp, value));
}
- (NSString *)setValueInt:(int)value forDP:(int)dp {
    return _consume(tuya_set_value_int(_handle, dp, value));
}
- (NSString *)setValueString:(NSString *)value forDP:(int)dp {
    return _consume(tuya_set_value_string(_handle, dp, value.UTF8String));
}
- (NSString *)setValueFloat:(double)value forDP:(int)dp {
    return _consume(tuya_set_value_float(_handle, dp, value));
}

- (NSString *)setValue:(id)value forDP:(int)dp {
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *n = value;
        if (strcmp(n.objCType, @encode(BOOL)) == 0 || strcmp(n.objCType, "c") == 0)
            return [self setValueBool:n.boolValue forDP:dp];
        if (strcmp(n.objCType, @encode(double)) == 0 || strcmp(n.objCType, "d") == 0)
            return [self setValueFloat:n.doubleValue forDP:dp];
        return [self setValueInt:n.intValue forDP:dp];
    }
    return [self setValueString:[value description] forDP:dp];
}

- (NSString *)turnOn:(int)dp  { return _consume(tuya_turn_on(_handle, dp)); }
- (NSString *)turnOff:(int)dp { return _consume(tuya_turn_off(_handle, dp)); }
- (NSString *)status   { return _consume(tuya_status(_handle)); }
- (NSString *)heartbeat { return _consume(tuya_heartbeat(_handle)); }

- (void)setDevice22:(NSString *)json { tuya_set_device22(_handle, json.UTF8String); }
- (BOOL)isDevice22 { return tuya_is_device22(_handle); }

@end
