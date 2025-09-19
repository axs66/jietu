#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <SpringBoard/SpringBoard.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <CoreFoundation/CoreFoundation.h>

// 设置偏好标识符
#define PREFS_IDENTIFIER "com.screenshotwatermark.preferences"
#define ENABLED_KEY "enabled"
#define WATERMARK_FOLDER_KEY "watermarkFolder"
#define FRAME_ENABLED_KEY "frameEnabled"

// ===================== 功能函数声明 =====================
BOOL isWatermarkEnabled(void);
BOOL isFrameEnabled(void);
UIImage* addWatermarkToImage(UIImage *image);
UIImage* addFrameToImage(UIImage *image);

// ===================== 偏好读取 =====================
BOOL isWatermarkEnabled() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%s.plist", PREFS_IDENTIFIER]];
    return prefs[ENABLED_KEY] ? [prefs[ENABLED_KEY] boolValue] : YES;
}

BOOL isFrameEnabled() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%s.plist", PREFS_IDENTIFIER]];
    return prefs[FRAME_ENABLED_KEY] ? [prefs[FRAME_ENABLED_KEY] boolValue] : YES;
}

// ===================== 图片处理函数 =====================
UIImage* addWatermarkToImage(UIImage *image) {
    // 调用 Watermark.x 提供的水印函数
    return Watermark_addWatermark(image);
}

UIImage* addFrameToImage(UIImage *image) {
    // 调用 Frame.x 提供的套壳函数
    return Frame_addFrame(image);
}

// ===================== Hook 示例：截图处理 =====================
%hook SBScreenShotController

- (void)saveScreenshot:(UIImage *)image {
    UIImage *processedImage = image;
    if (isWatermarkEnabled()) processedImage = addWatermarkToImage(processedImage);
    if (isFrameEnabled()) processedImage = addFrameToImage(processedImage);

    %orig(processedImage);
}

%end

// ===================== Hook 示例：相册选择处理 =====================
%hook UIImagePickerController

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
    UIImage *processedImage = originalImage;

    if (isWatermarkEnabled()) processedImage = addWatermarkToImage(processedImage);
    if (isFrameEnabled()) processedImage = addFrameToImage(processedImage);

    NSMutableDictionary *newInfo = [info mutableCopy];
    newInfo[UIImagePickerControllerOriginalImage] = processedImage;

    %orig(picker, newInfo);
}

%end

// ===================== 权限/安全检查 Hook =====================
%hook PHPhotoLibrary

+ (void)requestAuthorization:(void (^)(PHAuthorizationStatus status))handler {
    // 这里可以加自定义逻辑，比如检测是否有越狱标识或者设备黑名单
    %orig(handler);
}

%end

// ===================== 通知监听示例 =====================
void setupNotificationListener() {
    int notify_token;
    notify_register_dispatch("com.screenshotwatermark.update", &notify_token, dispatch_get_main_queue(), ^(int token){
        // 偏好更新时重新加载配置
        NSLog(@"[ScreenshotWatermark] Preferences updated.");
    });
}

// ===================== 插件初始化 =====================
%ctor {
    setupNotificationListener();
}
