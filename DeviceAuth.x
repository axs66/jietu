#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

static BOOL isDeviceAuthorized = NO;
static NSArray *validBase64UDIDs = nil;

static NSString* base64EncodeString(NSString *string) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

static void initializeValidUDIDs() {
    if (!validBase64UDIDs) {
        validBase64UDIDs = @[@"MDAwMDgxMjAtMDAxRTNDODYyRTk4QzAxRQ==",];
    }
}

static NSString* getDeviceUDID() {
    NSString *udid = @"";
    @try {
        void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        if (!handle) return @"";
        CFStringRef (*MGCopyAnswerFunc)(CFStringRef) = dlsym(handle, "MGCopyAnswer");
        if (!MGCopyAnswerFunc) { dlclose(handle); return @""; }
        CFStringRef udidCF = MGCopyAnswerFunc(CFSTR("UniqueDeviceID"));
        dlclose(handle);
        if (!udidCF) return @"";
        udid = (__bridge_transfer NSString *)udidCF;
        NSLog(@"[DeviceAuth] UDID Base64: %@", base64EncodeString(udid));
    } @catch (NSException *e) { udid = @""; }
    return udid;
}

static NSString* getAlternativeDeviceIdentifier() {
    NSString *identifier = @"";
    @try {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        identifier = [NSString stringWithUTF8String:machine];
        free(machine);
    } @catch (NSException *e) {}
    return identifier;
}

static BOOL isValidDevice() {
    initializeValidUDIDs();
    NSString *currentUDID = getDeviceUDID();
    if ([currentUDID isEqualToString:@""]) {
        getAlternativeDeviceIdentifier();
        return NO;
    }
    NSString *base64CurrentUDID = base64EncodeString(currentUDID);
    BOOL isValid = [validBase64UDIDs containsObject:base64CurrentUDID];
    NSLog(@"[DeviceAuth] Device validation: %@", isValid ? @"Passed" : @"Failed");
    isDeviceAuthorized = isValid;
    return isValid;
}

static BOOL fileExists(NSString *path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static void createDirectoryIfNotExists(NSString *path) {
    if (!isDeviceAuthorized) return;
    BOOL isDir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) NSLog(@"[DeviceAuth] Create dir error: %@", error);
    }
}
