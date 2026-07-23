// example.m — demonstrate libseatuya via Objective-C
//
// Build: clang -framework Foundation -lseatuya -I../include example.m Seatuya.m -o example

#import "Seatuya.h"
#import <Foundation/Foundation.h>

int main(void) {
    @autoreleasepool {
        NSString *deviceId = NSProcessInfo.processInfo.environment[@"TUYA_DEVICE_ID"]
                             ?: @"0123456789abcdef01234567";
        NSString *localKey = NSProcessInfo.processInfo.environment[@"TUYA_LOCAL_KEY"]
                             ?: @"0123456789abcdef";
        NSString *ip       = NSProcessInfo.processInfo.environment[@"TUYA_IP"]
                             ?: @"192.168.1.100";
        NSString *ver      = NSProcessInfo.processInfo.environment[@"TUYA_VERSION"]
                             ?: @"3.4";

        NSLog(@"seatuya version: %@", [SeatuyaDevice version]);

        SeatuyaDevice *dev = [[SeatuyaDevice alloc] initWithDeviceId:deviceId
                                                              address:ip
                                                             localKey:localKey
                                                              version:ver];
        if (!dev) {
            NSLog(@"ERROR: Could not create device handle");
            return 1;
        }

        NSLog(@"Connected: %@", dev.isConnected ? @"YES" : @"NO");
        NSLog(@"turn_on: %@", [dev turnOn:1]);
        NSLog(@"status: %@", [dev status]);
        NSLog(@"turn_off: %@", [dev turnOff:1]);
    }
    NSLog(@"Done.");
    return 0;
}
