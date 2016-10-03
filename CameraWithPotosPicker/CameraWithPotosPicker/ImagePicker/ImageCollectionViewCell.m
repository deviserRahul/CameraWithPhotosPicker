//
//  ImageCollectionViewCell.m
//  PhotoPicker
//
//  Created by Rahul on 18/09/16.
//  Copyright © 2016 Apple Inc. All rights reserved.
//

#import "ImageCollectionViewCell.h"

@implementation ImageCollectionViewCell


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _imgView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self setAlpha:ALPHA_UNSELECTED];
        self.layer.borderColor = [UIColor clearColor].CGColor;
        self.layer.borderWidth = 2.0;
        [self.contentView addSubview:_imgView];
    }
    return self;
}


@end
