# ImagePickerController
An iOS PhotoKit-compatible replacement for UIImagePickerController with multi-select support
- The first version only allows picking of images. I may add video support in the future. 

# Usage

// Present the image picker
- (void)onAddTapped:(id)sender {
    ImagePickerController *picker = [[ImagePickerController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    picker.delegate = self;
    [self presentViewController:navigation animated:YES completion:nil];
}

// An example of handling the delegate callback
- (void)imagePickerController:(ImagePickerController *)controller didPickAssets:(NSArray *)assets {

    UIAlertView *alert = nil;
    if (assets.count > 1) {
        alert = [[UIAlertView alloc] initWithTitle:@"Importing…"
                                           message:nil
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:nil];
        [alert show];
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        for (PHAsset *asset in assets) {
            CLLocation *location = asset.location;
            NSDate *creationDate = asset.creationDate;            
            NSData *data = [asset ts_imageData];
            // Do something with this ^ data here
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert dismissWithClickedButtonIndex:-1 animated:YES];
        });
    });
    
    [self dismissViewControllerAnimated:YES completion:nil];
}