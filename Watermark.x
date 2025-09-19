#import <UIKit/UIKit.h>
#import "DeviceAuth.x"

#define PREFS_IDENTIFIER "com.screenshotwatermark.preferences"
#define ENABLED_KEY "enabled"
#define WATERMARK_FOLDER_KEY "watermarkFolder"
#define WATERMARK_OPACITY_KEY "watermarkOpacity"
#define WATERMARK_BLEND_MODE_KEY "watermarkBlendMode"
#define DELETE_ORIGINAL_KEY "deleteOriginal"

static BOOL isWatermarkEnabled() {
    if (!isDeviceAuthorized) return NO;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    return prefs ? [[prefs objectForKey:@ENABLED_KEY] boolValue] : YES;
}

static NSString *getSelectedWatermarkFolder() {
    if (!isDeviceAuthorized) return nil;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *folder = [prefs objectForKey:@WATERMARK_FOLDER_KEY];
    if (!folder || [folder isEqualToString:@"默认水印"] || [folder isEqualToString:@""]) return nil;
    return folder;
}

static CGFloat getWatermarkOpacity() {
    if (!isDeviceAuthorized) return 0.6;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSNumber *opacity = [prefs objectForKey:@WATERMARK_OPACITY_KEY];
    return opacity ? [opacity floatValue] : 0.6;
}

static CGBlendMode getWatermarkBlendMode() {
    if (!isDeviceAuthorized) return kCGBlendModeNormal;
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *blendMode = [prefs objectForKey:@WATERMARK_BLEND_MODE_KEY];
    if (!blendMode) return kCGBlendModeNormal;
    if ([blendMode isEqualToString:@"叠加"]) return kCGBlendModeOverlay;
    if ([blendMode isEqualToString:@"滤色"]) return kCGBlendModeScreen;
    if ([blendMode isEqualToString:@"变亮"]) return kCGBlendModeLighten;
    if ([blendMode isEqualToString:@"强光"]) return kCGBlendModeHardLight;
    return kCGBlendModeNormal;
}

static NSString *getWatermarkPathForImage(UIImage *image) {
    if (!isDeviceAuthorized) return @"";
    NSString *selectedFolder = getSelectedWatermarkFolder();
    NSString *syBasePath = @"/var/mobile/SY";
    createDirectoryIfNotExists(syBasePath);

    BOOL isLandscape = image.size.width > image.size.height;
    NSString *portraitFilename = @"水印.png";
    NSString *landscapeFilename = @"水印横屏.png";
    NSString *targetFilename = isLandscape ? landscapeFilename : portraitFilename;

    if (selectedFolder) {
        NSString *selectedPath = [syBasePath stringByAppendingPathComponent:selectedFolder];
        NSString *watermarkPath = [selectedPath stringByAppendingPathComponent:targetFilename];
        if (fileExists(watermarkPath)) return watermarkPath;
        NSString *defaultWatermarkPath = [selectedPath stringByAppendingPathComponent:portraitFilename];
        if (fileExists(defaultWatermarkPath)) return defaultWatermarkPath;
    }

    NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:nil];
    for (NSString *subdir in subdirs) {
        NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
        NSString *watermarkPath = [fullPath stringByAppendingPathComponent:targetFilename];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:nil] && fileExists(watermarkPath)) return watermarkPath;
    }

    NSString *rootPath = [syBasePath stringByAppendingPathComponent:targetFilename];
    if (fileExists(rootPath)) return rootPath;
    return rootPath;
}

static UIImage *addWatermarkToImage(UIImage *originalImage) {
    if (!isDeviceAuthorized || !isWatermarkEnabled()) return originalImage;
    NSString *watermarkPath = getWatermarkPathForImage(originalImage);
    if (!fileExists(watermarkPath)) return originalImage;
    UIImage *watermark = [UIImage imageWithContentsOfFile:watermarkPath];
    if (!watermark) return originalImage;

    CGFloat opacity = getWatermarkOpacity();
    CGBlendMode blendMode = getWatermarkBlendMode();

    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    [originalImage drawInRect:CGRectMake(0, 0, originalImage.size.width, originalImage.size.height)];

    CGFloat targetWidth = originalImage.size.width;
    CGFloat targetHeight = originalImage.size.height;
    CGFloat watermarkAspect = watermark.size.width / watermark.size.height;
    CGFloat screenAspect = originalImage.size.width / originalImage.size.height;
    if (watermarkAspect > screenAspect) targetHeight = targetWidth / watermarkAspect;
    else targetWidth = targetHeight * watermarkAspect;

    CGFloat centerX = (originalImage.size.width - targetWidth) / 2.0;
    CGFloat centerY = (originalImage.size.height - targetHeight) / 2.0;
    [watermark drawInRect:CGRectMake(centerX, centerY, targetWidth, targetHeight) blendMode:blendMode alpha:opacity];

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}
