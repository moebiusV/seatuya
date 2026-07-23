// Seatuya.h — Objective-C bindings for libseatuya
//
// Pure Objective-C wrapper around the C ABI.  The opaque tuya_device_t*
// is wrapped in an ObjC class with full memory management (ARC or manual).
//
// Usage:
//   #import "Seatuya.h"
//   SeatuyaDevice *dev = [[SeatuyaDevice alloc] initWithDeviceId:id
//                                                       address:@"192.168.1.100"
//                                                      localKey:key
//                                                       version:@"3.4"];
//   NSLog(@"%@", [dev turnOn:1]);
//   NSLog(@"%@", [dev status]);
//   // dealloc disconnects and destroys automatically

#import <Foundation/Foundation.h>
#import <seatuya/seatuya.h>

NS_ASSUME_NONNULL_BEGIN

@interface SeatuyaDevice : NSObject

@property (nonatomic, readonly) tuya_device_t *_Nullable handle;

// Lifecycle
+ (NSString *)version;
- (nullable instancetype)initWithDeviceId:(NSString *)deviceId
                                  address:(NSString *)address
                                 localKey:(NSString *)localKey
                                  version:(NSString *)version;
- (nullable instancetype)initWithVersion:(NSString *)version; // alloc only

// Credentials
- (void)setCredentialsWithDeviceId:(NSString *)deviceId localKey:(NSString *)localKey;
- (NSString *)deviceId;
- (NSString *)localKey;
- (NSString *)ip;

// Connection
- (BOOL)connect:(NSString *)hostname;
- (void)disconnect;
- (BOOL)isConnected;
- (BOOL)reconnect;

// Retry
- (void)setRetryLimit:(int)limit;
- (void)setRetryDelay:(int)ms;
- (int)retryLimit;
- (int)retryDelay;

// Session
- (BOOL)negotiateSession:(NSString *)key;

// State
- (int)protocolVersion;
- (int)sessionState;
- (int)socketState;
- (int)lastError;

// Async
- (void)setAsyncMode:(BOOL)flag;

// High-level round-trip (each returns JSON string or nil)
- (nullable NSString *)setValueBool:(BOOL)value forDP:(int)dp;
- (nullable NSString *)setValueInt:(int)value forDP:(int)dp;
- (nullable NSString *)setValueString:(NSString *)value forDP:(int)dp;
- (nullable NSString *)setValueFloat:(double)value forDP:(int)dp;
- (nullable NSString *)setValue:(id)value forDP:(int)dp; // type-dispatch
- (nullable NSString *)turnOn:(int)dp;
- (nullable NSString *)turnOff:(int)dp;
- (nullable NSString *)status;
- (nullable NSString *)heartbeat;

// device22
- (void)setDevice22:(NSString *)nullDPSJson;
- (BOOL)isDevice22;

@end

NS_ASSUME_NONNULL_END
