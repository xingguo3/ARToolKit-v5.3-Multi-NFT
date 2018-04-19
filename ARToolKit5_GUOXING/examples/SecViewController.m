//
//  SecViewController.m
//  ARToolKit5iOS
//
//  Created by GUO Xing on 13/4/2018.
//

#import "SecViewController.h"

@interface SecViewController ()

@end

@implementation SecViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}


- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
//    int i = self.index;
//    printf(i);
    printf("\n");
    UIImageView *imageview = [[UIImageView alloc] initWithFrame:(CGRectMake(100,200,100,100))];
    NSString *tmp = [NSString stringWithFormat:@"vw%ld.png", (long)self.index];
//    NSLog(tmp);
    imageview.image = [UIImage imageNamed:tmp];
    self.screenNumber.image = imageview.image;

    self.screenNumber  = [[UIImageView alloc] initWithFrame:(CGRectMake(100,200,100,100))];
    self.screenNumber.image =[UIImage imageNamed:tmp];
    
    NSInteger *pageN = self.index;
    if((int)pageN == 0){
        self.labelNumber.text = @"Yuncheng";
    }else if ((int)pageN == 1){
        self.labelNumber.text = @"Guan Yu";
    }else if ((int)pageN == 3){
        self.labelNumber.text = @"Salt Lake";
    }else if ((int)pageN == 2){
        self.labelNumber.text = @"Pujiu Temple";
    }else if ((int)pageN == 5){
        self.labelNumber.text = @"AR Tour";
    }else if ((int)pageN == 4){
        self.labelNumber.text = @"SIMA Guang";
    }else if ((int)pageN == 6){
        self.labelNumber.text = @"downloads";
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





- (void)dealloc {
//    [_pageView release];
//    [_screenNumber release];
    [_labelNumber release];
    [_screenNumber release];
    [super dealloc];
}

@end
