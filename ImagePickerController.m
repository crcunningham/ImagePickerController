// The MIT License (MIT)
//
// Copyright (c) 2015 Chris Cunningham
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "ImagePickerController.h"

#define AssetCellIdentifier @"AssetCellIdentifier"

@interface AssetCell : UICollectionViewCell

@property (nonatomic, strong) PHAsset *asset;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *checkmarkImageView;
@property (nonatomic, assign) PHImageRequestID imageRequestID;

@end

@implementation AssetCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.imageRequestID = PHInvalidImageRequestID;
        
        self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.imageView.clipsToBounds = YES;
        self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:self.imageView];
        
        UIImage *checkmarkImage = [UIImage imageNamed:@"check"];
        self.checkmarkImageView = [[UIImageView alloc] initWithImage:checkmarkImage];
        self.checkmarkImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.checkmarkImageView sizeToFit];
        [self.contentView addSubview:self.checkmarkImageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.imageView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    self.imageView.bounds = self.bounds;
    
    CGFloat checkmarkX = self.bounds.size.width - self.checkmarkImageView.bounds.size.width - 4.0;
    CGRect checkmarkFrame = CGRectMake(checkmarkX,
                                       4.0,
                                       self.checkmarkImageView.bounds.size.width,
                                       self.checkmarkImageView.bounds.size.height);
    checkmarkFrame = CGRectIntegral(checkmarkFrame);
    self.checkmarkImageView.center = CGPointMake(CGRectGetMidX(checkmarkFrame), CGRectGetMidY(checkmarkFrame));
}

- (void)prepareForReuse {
    [self cancelImageRequest];
    self.imageView.image = nil;
}

- (void)cancelImageRequest {
    if (self.imageRequestID != PHInvalidImageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
        self.imageRequestID = PHInvalidImageRequestID;
    }
}

- (void)setAsset:(PHAsset *)asset {
    if (_asset != asset) {
        _asset = asset;
        
        [self cancelImageRequest];
        
        if (_asset) {
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            CGFloat scale = [UIScreen mainScreen].scale;
            CGSize size = CGSizeMake(self.bounds.size.width * scale, self.bounds.size.height * scale);
            self.imageRequestID = [[PHImageManager defaultManager] requestImageForAsset:_asset
                                                                             targetSize:size
                                                                            contentMode:PHImageContentModeAspectFill
                                                                                options:options
                                                                          resultHandler:^(UIImage *result, NSDictionary *info) {
                                                                              if (_asset == asset) {
                                                                                  self.imageView.image = result;
                                                                              }
                                                                          }];
        }
        
    }
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    
    self.checkmarkImageView.hidden = !selected;
    self.imageView.alpha = selected ? 0.7 : 1.0;
}

@end

@interface ImagePickerController () <UIAlertViewDelegate>

@property (nonatomic, strong) NSArray *assets;
@property (nonatomic, strong) NSMutableSet *selectedAssets;
@property (nonatomic, strong) UIImageView *previewImageView;

@end

@implementation ImagePickerController

- (instancetype)init {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat w = ([UIScreen mainScreen].bounds.size.width / 4) - 1;
    layout.itemSize = CGSizeMake(w, w);
    layout.minimumInteritemSpacing = 1.0;
    layout.minimumLineSpacing = 1.0;
    self = [super initWithCollectionViewLayout:layout];
    if (self) {
        self.selectedAssets = [[NSMutableSet alloc] init];
        self.title = NSLocalizedString(@"Choose Photos", @"Image picker title.");

        UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
        self.navigationItem.leftBarButtonItem = cancelItem;
        
        UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDone:)];
        doneItem.enabled = NO;
        self.navigationItem.rightBarButtonItem = doneItem;
    }
    return self;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.collectionView registerClass:AssetCell.class forCellWithReuseIdentifier:AssetCellIdentifier];
    self.collectionView.backgroundColor = [UIColor whiteColor];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [self.collectionView addGestureRecognizer:tap];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    press.minimumPressDuration = 0.15;
    [self.collectionView addGestureRecognizer:press];
    
    if (PHPhotoLibrary.authorizationStatus == PHAuthorizationStatusAuthorized) {
        [self fetchAssets];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (PHPhotoLibrary.authorizationStatus == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
           dispatch_async(dispatch_get_main_queue(), ^{
               if (status == PHAuthorizationStatusAuthorized) {
                   [self fetchAssets];
                   
                   
               } else {
                   [self showAssetsDeniedMessage];
               }
           });
        }];
    } else if (PHPhotoLibrary.authorizationStatus == PHAuthorizationStatusDenied) {
        [self showAssetsDeniedMessage];
    } else {
        // authorized
    }
}

#pragma mark - Assets

- (void)showAssetsDeniedMessage {
    NSString *title = NSLocalizedString(@"Enable Access", @"Title for an alert that lets the user know that they need to enable access to their photo library");
    NSString *message = NSLocalizedString(@"Access to your photo library can be enabled in the Settings app.", @"Message for an alert that lets the user know that they need to enable access to their photo library");
    NSString *cancel = NSLocalizedString(@"Cancel", @"Alert cancel button");
    NSString *settings = NSLocalizedString(@"Settings", @"Settings button");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:cancel
                                          otherButtonTitles:settings, nil];
    [alert show];
}

- (void)fetchAssets {
    __weak __typeof(self) weak = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
        fetchOptions.includeHiddenAssets = NO;
        fetchOptions.includeAllBurstAssets = NO;
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO],
                                         [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:fetchOptions];
        
        NSMutableArray *assets = [[NSMutableArray alloc] init];
        [fetchResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [assets addObject:obj];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            weak.assets = assets;
            [weak.collectionView reloadData];
        });
    });
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.firstOtherButtonIndex) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
    
    [self.delegate imagePickerControllerDidCancel:self];
}

#pragma mark - Collection View

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AssetCell *cell = (AssetCell *)[collectionView dequeueReusableCellWithReuseIdentifier:AssetCellIdentifier forIndexPath:indexPath];
    PHAsset *asset = self.assets[indexPath.item];
    cell.asset = asset;
    cell.selected = [self.selectedAssets containsObject:asset];
    
    return cell;
}

#pragma mark - Actions

- (void)onDone:(UIButton *)sender {
    [self.delegate imagePickerController:self didPickAssets:self.selectedAssets.allObjects];
}

- (void)onCancel:(UIButton *)sender {
    [self.delegate imagePickerControllerDidCancel:self];
}

- (void)onTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[recognizer locationInView:self.collectionView]];
        if (indexPath) {
            AssetCell *cell = (AssetCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            PHAsset *asset = self.assets[indexPath.item];
            if ([self.selectedAssets containsObject:asset]) {
                [self.selectedAssets removeObject:asset];
                cell.selected = NO;
            } else {
                [self.selectedAssets addObject:asset];
                cell.selected = YES;
            }
            
            self.navigationItem.rightBarButtonItem.enabled = self.selectedAssets.count > 0;
            
            if (self.selectedAssets.count > 0) {
                NSString *countNumber = [NSNumberFormatter localizedStringFromNumber:@(self.selectedAssets.count)
                                                                         numberStyle:NSNumberFormatterDecimalStyle];
                NSString *numberFormat = NSLocalizedString(@"%@ Selected", @"Image picker title. The variable is a localized number");
                self.title = [NSString stringWithFormat:numberFormat, countNumber];
            } else {
                self.title = NSLocalizedString(@"Choose Photos", @"Image picker title.");
            }
        }
    }
}

- (void)onLongPress:(UILongPressGestureRecognizer *)recognizer {
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[recognizer locationInView:self.collectionView]];
        if (indexPath) {
            PHAsset *asset = self.assets[indexPath.item];
            
            [self.previewImageView removeFromSuperview];
            UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
            self.previewImageView = previewImageView;
            self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
            self.previewImageView.backgroundColor = [UIColor blackColor];
            [self.view addSubview:self.previewImageView];
            
            self.previewImageView.alpha = 0.0;
            [UIView animateWithDuration:0.1 animations:^{
                self.previewImageView.alpha = 1.0;
            }];
            
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            CGFloat scale = [UIScreen mainScreen].scale;
            CGSize size = CGSizeMake(self.view.bounds.size.width * scale, self.view.bounds.size.height * scale);
            [[PHImageManager defaultManager] requestImageForAsset:asset
                                                       targetSize:size
                                                      contentMode:PHImageContentModeAspectFill
                                                          options:options
                                                    resultHandler:^(UIImage *result, NSDictionary *info) {
                                                        if (self.previewImageView == previewImageView) {
                                                            self.previewImageView.image = result;
                                                        }
                                                    }];
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        
        [UIView animateWithDuration:0.1 animations:^{
            self.previewImageView.alpha = 1.0;
        } completion:^(BOOL finished) {
            [self.previewImageView removeFromSuperview];
        }];
    }
}

@end

@implementation PHAsset (TSImagePickerHelpers)

- (NSData *)ts_imageData {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES;
    
    __block NSData *data = nil;
    [[PHImageManager defaultManager] requestImageDataForAsset:self
                                                      options:options
                                                resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                                                    data = imageData;
                                                }];
    return data;
}

@end


