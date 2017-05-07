//
//  QRCodeWindowController.h
//  shadowsocks
//
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface SWBQRCodeWindowController : NSWindowController

@property (nonatomic, copy) NSString *qrCode;
@property (nonatomic, copy) NSString *title;

@property (nonatomic, weak) NSTextField *titleTextField;
@property (nonatomic, weak) NSImageView *imageView;

- (IBAction) copyQRCode: (id) sender;

@end
