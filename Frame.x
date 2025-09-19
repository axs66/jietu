#import <UIKit/UIKit.h>
#import "DeviceAuth.x"

#define FRAME_ENABLED_KEY "frameEnabled"
#define FRAME_FOLDER_KEY "frameFolder"

static BOOL isFrameEnabled() {
    if (!isDeviceAuthorized) return NO;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    return prefs ? [[prefs objectForKey:@FRAME_ENABLED_KEY] boolValue] : NO;
}

static NSString *getFrameFolder() {
    if (!isDeviceAuthorized) return nil;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *folder = [prefs objectForKey:@FRAME_FOLDER_KEY];
    if (!folder || [folder isEqualToString:@"默认套壳"] || [folder isEqualToString:@""]) return nil;
    return folder;
}

static NSString *getFramePath() {
    NSString *selectedFolder = getFrameFolder();
    NSString *syBasePath = @"/var/mobile/SY";
    createDirectoryIfNotExists(syBasePath);

    if (selectedFolder) {
        NSString *selectedPath = [syBasePath stringByAppendingPathComponent:selectedFolder];
        NSString *framePath = [selectedPath stringByAppendingPathComponent:@"套壳.png"];
        if (fileExists(framePath)) return framePath;
    }

    NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:nil];
    for (NSString *subdir in subdirs) {
        NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
        NSString *framePath = [fullPath stringByAppendingPathComponent:@"套壳.png"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:nil] && fileExists(framePath)) return framePath;
    }

    return [syBasePath stringByAppendingPathComponent:@"套壳.png"];
}

// 可以继续保留原来的解析配置和透视变换逻辑
static UIImage *addFrameToImage(UIImage *originalImage) {
    if (!isDeviceAuthorized || !isFrameEnabled()) return originalImage;
    NSString *framePath = getFramePath();
    if (!fileExists(framePath)) return originalImage;
    UIImage *frameImage = [UIImage imageWithContentsOfFile:framePath];
    if (!frameImage) return originalImage;

    // 可加入原来的 JSON config 解析、透视变换逻辑
    UIGraphicsBeginImageContextWithOptions(frameImage.size, NO, frameImage.scale);
    [originalImage drawInRect:CGRectMake(0,0,frameImage.size.width,frameImage.size.height)];
    [frameImage drawInRect:CGRectMake(0,0,frameImage.size.width,frameImage.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

// ===================== Frame 功能 =====================
UIImage* Frame_addFrame(UIImage *image) {
    if (!image) return nil;

    CGSize size = image.size;
    CGFloat borderWidth = 20.0;

    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    [image drawAtPoint:CGPointZero];

    // 绘制边框
    UIBezierPath *borderPath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, size.width, size.height)];
    [[UIColor colorWithWhite:0 alpha:0.3] setStroke];
    borderPath.lineWidth = borderWidth;
    [borderPath stroke];

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}
