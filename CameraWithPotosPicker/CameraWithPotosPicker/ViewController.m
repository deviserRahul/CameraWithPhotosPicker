//
//  ViewController.m
//  CameraWithPotosPicker
//
//  Created by Rahul on 25/09/16.
//  Copyright © 2016 rpant. All rights reserved.
//

#import "ViewController.h"
#import <Photos/Photos.h>
#import "ImageCollectionViewCell.h"

#define MAX_IMAGES  10

@interface ViewController() <UINavigationControllerDelegate ,UIImagePickerControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, PHPhotoLibraryChangeObserver>

@property (nonatomic, weak) IBOutlet UIImageView            *imageView;
@property (nonatomic, weak) IBOutlet UIToolbar              *toolBar;
@property (nonatomic, weak) IBOutlet UIView                 *overlayView;
@property (nonatomic, weak) IBOutlet UICollectionView       *viewCollectionGallery;
@property (nonatomic, weak) IBOutlet UIButton               *btnOk;
@property (nonatomic, weak) IBOutlet UIButton               *btnOpenGallery;
@property (nonatomic, weak) IBOutlet UIButton               *btnTakePhoto;
@property (nonatomic, weak) IBOutlet UIButton               *btnCancel;

@property (nonatomic) UIImagePickerController               *imagePickerController;
@property (nonatomic) PHFetchResult                         *fetchResults;
@property (nonatomic) NSMutableArray                        *arrAssets;
@property (nonatomic) NSInteger                             lastSelectedIndex;
@property (nonatomic) NSTimer                               *cameraTimer;
@property (nonatomic) BOOL                                  canSelectMultipleImages;

@end

//====================================================================================================================================

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _canSelectMultipleImages = YES;
    _arrAssets = [[NSMutableArray alloc] init];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if ([self isMovingFromParentViewController])
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (IBAction)showImagePickerForCamera:(id)sender
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        NSLog(@"No camera man!! :(");
        return;
    }
    
    [self showImagePickerWithMultipeSelection:YES];
}

- (void)showImagePickerWithMultipeSelection:(BOOL)allow
{
    if (self.imageView.isAnimating)
    {
        [self.imageView stopAnimating];
    }
    
    _canSelectMultipleImages = allow;
    _lastSelectedIndex = -1;
    
    if (_fetchResults == nil)
    {
        [self checkandFetchGalleryData];
    }
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePickerController.delegate = self;
    imagePickerController.modalPresentationStyle = UIModalPresentationFullScreen;
    imagePickerController.showsCameraControls = NO;
    
    [[NSBundle mainBundle] loadNibNamed:@"ImagePickerOverlay" owner:self options:nil];
    [self initializeCameraOverlay];
    self.overlayView.frame = imagePickerController.cameraOverlayView.frame;
    imagePickerController.cameraOverlayView = self.overlayView;
    self.overlayView = nil;
    _imagePickerController = imagePickerController;
    
    [self presentViewController:_imagePickerController animated:NO completion:nil];
}

- (void)initializeCameraOverlay
{
    [_viewCollectionGallery registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"galleryImage"];
    
    [_btnOk          setExclusiveTouch:YES];
    [_btnOpenGallery setExclusiveTouch:YES];
    [_btnCancel      setExclusiveTouch:YES];
    [_btnTakePhoto   setExclusiveTouch:YES];
}

# pragma mark IBAction

- (IBAction)sel_btnCancel:(id)sender
{
    [_arrAssets removeAllObjects];
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (IBAction)sel_btnTakePhoto:(id)sender
{
    [_imagePickerController takePicture];
}

- (IBAction)sel_openGallery:(id)sender
{
    // open gallery
}

- (IBAction)sel_btnOK:(id)sender
{
    NSMutableArray *arrSelectedImages = [[NSMutableArray alloc]initWithCapacity:2];
    
    for (PHAsset *asset in _arrAssets)
    {
        PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.synchronous = true;
        
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:PHImageManagerMaximumSize
                                                  contentMode:PHImageContentModeDefault
                                                      options:requestOptions
                                                resultHandler:^void(UIImage *image, NSDictionary *info) {
                                                    [arrSelectedImages addObject:image];
                                                }];
    }
    
    if (arrSelectedImages.count)
    {
        [self pickedImages:[NSArray arrayWithArray:arrSelectedImages]];
    }
    
    [_arrAssets removeAllObjects];
    
    [self dismissViewControllerAnimated:NO completion:nil];
}


#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    
    if (image)
        [self pickedImages:[NSArray arrayWithObject:image]];
    
    [_arrAssets removeAllObjects];
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [_arrAssets removeAllObjects];
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - UICollectionViewDelegate


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _fetchResults.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = @"galleryImage";
    ImageCollectionViewCell *imageCell = (ImageCollectionViewCell*) [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    [[imageCell imgView] setImage:nil];
    PHAsset *asset = [_fetchResults objectAtIndex:indexPath.row];
    [self setAssetThumbnail:asset forSize:CGSizeMake(collectionView.frame.size.width, collectionView.frame.size.height) onView:[imageCell imgView]];
    [self updateUIForCell:imageCell forAsset:asset];
    return imageCell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [_fetchResults objectAtIndex:indexPath.row];
    
    if (asset)
    {
        BOOL desectingImage = [_arrAssets containsObject:asset];
        
        if ([_arrAssets count] >= MAX_IMAGES && !desectingImage)
        {
            AudioServicesPlaySystemSound(1053);
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        
        if (_canSelectMultipleImages)
        {
            if (desectingImage)
                [_arrAssets removeObject:asset];
            else
                [_arrAssets addObject:asset];
        }
        else
        {
            if (desectingImage)
            {
                [_arrAssets removeObject:asset];
                _lastSelectedIndex = -1;
            }
            else
            {
                [_arrAssets removeAllObjects];
                [_arrAssets addObject:asset];
                
                if (_lastSelectedIndex >= 0)
                {
                    ImageCollectionViewCell *lastSelectedCell = (ImageCollectionViewCell *)[_viewCollectionGallery cellForItemAtIndexPath:[NSIndexPath indexPathForRow:_lastSelectedIndex inSection:0]];
                    [lastSelectedCell setAlpha:ALPHA_UNSELECTED];
                    lastSelectedCell.layer.borderColor = [UIColor clearColor].CGColor;
                }
                
                _lastSelectedIndex = indexPath.row;
            }
        }
        
        ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
        [self updateUIForCell:selectedCell forAsset:asset];
        [_btnOk setEnabled:_arrAssets.count != 0];
    }
}

#pragma mark - Utilities

- (void)pickedImages:(NSArray *)arrImages
{
    // Dismiss the image picker.
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if ([arrImages count] > 0)
    {
        if ([arrImages count] == 1)
        {
            // Camera took a single picture.
            [self.imageView setImage:[arrImages firstObject]];
        }
        else
        {
            // Camera took multiple pictures; use the list of images for animation.
            self.imageView.animationImages = arrImages;
            self.imageView.animationDuration = 5.0;    // Show each captured photo for 5 seconds.
            self.imageView.animationRepeatCount = 0;   // Animate forever (show all photos).
            [self.imageView startAnimating];
        }
    }
    
    _imagePickerController = nil;
}

- (void)updateUIForCell:(ImageCollectionViewCell *)cell forAsset:(PHAsset *)asset
{
    if ([_arrAssets containsObject:asset])
    {
        [cell setAlpha:1];
        cell.layer.borderColor = [UIColor greenColor].CGColor;
    }
    else
    {
        [cell setAlpha:ALPHA_UNSELECTED];
        cell.layer.borderColor = [UIColor clearColor].CGColor;
    }
}

- (void)setAssetThumbnail:(PHAsset*) asset forSize:(CGSize)size onView:(UIImageView *)imageView
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSInteger retinaScale = [UIScreen mainScreen].scale;
        CGSize newsize = CGSizeMake(size.width*retinaScale, size.height*retinaScale);
        
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.resizeMode = PHImageRequestOptionsResizeModeExact;
        options.synchronous = YES;
        
        CGFloat cropSideLength = MIN(asset.pixelWidth, asset.pixelHeight);
        CGRect square = CGRectMake(0, 0, cropSideLength, cropSideLength);
        options.normalizedCropRect = CGRectApplyAffineTransform(square, CGAffineTransformMakeScale(1.0 / asset.pixelWidth, 1.0 / asset.pixelHeight));
        
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:newsize
                                                  contentMode:PHImageContentModeAspectFit
                                                      options:options
                                                resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                                                    
                                                    dispatch_async( dispatch_get_main_queue(), ^{
                                                        [imageView setImage:result];
                                                    });
                                                }];
    });
}

- (void)fetchGalleryData
{
    PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    _fetchResults = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:allPhotosOptions];
}

- (void)photoLibraryDidChange:(PHChange *)changeInfo
{
    PHFetchResultChangeDetails *changeDetail = [changeInfo changeDetailsForFetchResult:_fetchResults];
    if (changeDetail && [changeDetail hasIncrementalChanges])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fetchGalleryData];
            [_viewCollectionGallery reloadData];
        });
    }
}

- (void)checkandFetchGalleryData
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    if (status == PHAuthorizationStatusAuthorized)
    {
        [self fetchGalleryData];
    }
    else if (status == PHAuthorizationStatusNotDetermined)
    {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            
            if (status == PHAuthorizationStatusAuthorized) {
                [self fetchGalleryData];
                
                dispatch_async(dispatch_get_main_queue(), ^ {
                    [_viewCollectionGallery reloadData];
                });
            }
        }];
    }
}

@end
