//
//  ExchangeCreateViewController.m
//  Blockchain
//
//  Created by kevinwu on 10/23/17.
//  Copyright © 2017 Blockchain Luxembourg S.A. All rights reserved.
//

#import "ExchangeCreateViewController.h"
#import "FromToView.h"
#import "Blockchain-Swift.h"
#import "ContinueButtonInputAccessoryView.h"
#import "ExchangeTrade.h"
#import "ExchangeConfirmViewController.h"
#import "BCNavigationController.h"
#import "NSNumberFormatter+Currencies.h"

#define COLOR_EXCHANGE_BACKGROUND_GRAY UIColorFromRGB(0xf5f6f8)

#define DICTIONARY_KEY_TRADE_MINIMUM @"minimum"
#define DICTIONARY_KEY_TRADE_MAX_LIMIT @"maxLimit"

#define IMAGE_NAME_SWITCH_CURRENCIES @"switch_currencies"

@interface ExchangeCreateViewController () <UITextFieldDelegate, FromToButtonDelegate, AddressSelectionDelegate, ContinueButtonInputAccessoryViewDelegate>

@property (nonatomic) FromToView *fromToView;

@property (nonatomic) UILabel *fiatLabel;

@property (nonatomic) UILabel *leftLabel;
@property (nonatomic) UILabel *rightLabel;

@property (nonatomic) UIButton *assetToggleButton;

// Digital asset input
@property (nonatomic) BCSecureTextField *topLeftField;
@property (nonatomic) BCSecureTextField *topRightField;
@property (nonatomic) BCSecureTextField *btcField;
@property (nonatomic) BCSecureTextField *ethField;

// Fiat input
@property (nonatomic) BCSecureTextField *bottomLeftField;
@property (nonatomic) BCSecureTextField *bottomRightField;

@property (nonatomic) UITextView *errorTextView;

@property (nonatomic) id amount;
@property (nonatomic) int btcAccount;

@property (nonatomic) NSString *fromSymbol;
@property (nonatomic) NSString *toSymbol;
@property (nonatomic) NSString *fromAddress;
@property (nonatomic) NSString *toAddress;

@property (nonatomic) NSURLSessionDataTask *currentDataTask;

// uint64_t or NSDecimalNumber
@property (nonatomic) id minimum;
@property (nonatomic) id maximum;
@property (nonatomic) id maximumHardLimit;
@property (nonatomic) id availableBalance;
@property (nonatomic) id fee;

@property (nonatomic) UIActivityIndicatorView *spinner;

@property (nonatomic) ContinueButtonInputAccessoryView *continuePaymentAccessoryView;
@property (nonatomic) UIButton *continueButton;
@end

@implementation ExchangeCreateViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupViews];
    
    self.btcAccount = [app.wallet getDefaultAccountIndex];
    
    [self selectFromBitcoin];
    [self selectToEther];
    
    self.amount = 0;
    
    [self disablePaymentButtons];
    
    [self getRate];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    navigationController.headerTitle = BC_STRING_EXCHANGE;
}

- (void)setupViews
{
    self.view.backgroundColor = COLOR_EXCHANGE_BACKGROUND_GRAY;
    
    CGFloat windowWidth = WINDOW_WIDTH;
    FromToView *fromToView = [[FromToView alloc] initWithFrame:CGRectMake(0, DEFAULT_HEADER_HEIGHT + 16, windowWidth, 96) enableToTextField:NO];
    fromToView.delegate = self;
    [self.view addSubview:fromToView];
    self.fromToView = fromToView;
    
    UIView *amountView = [[UIView alloc] initWithFrame:CGRectMake(0, fromToView.frame.origin.y + fromToView.frame.size.height + 1, windowWidth, 100)];
    amountView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:amountView];
    
    UILabel *topLeftLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 40, 30)];
    topLeftLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    topLeftLabel.textColor = COLOR_TEXT_DARK_GRAY;
    topLeftLabel.text = CURRENCY_SYMBOL_BTC;
    self.leftLabel = topLeftLabel;
    [amountView addSubview:topLeftLabel];
    
    UIButton *assetToggleButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 12, 30, 30)];
    assetToggleButton.center = CGPointMake(windowWidth/2, assetToggleButton.center.y);
    [assetToggleButton addTarget:self action:@selector(assetToggleButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    UIImage *buttonImage = [UIImage imageNamed:IMAGE_NAME_SWITCH_CURRENCIES];
    [assetToggleButton setImage:buttonImage forState:UIControlStateNormal];
    assetToggleButton.imageView.transform = CGAffineTransformMakeRotation(M_PI/2);
    [amountView addSubview:assetToggleButton];
    self.assetToggleButton = assetToggleButton;
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = assetToggleButton.center;
    [amountView addSubview:self.spinner];
    self.spinner.hidden = YES;
    
    UILabel *topRightLabel = [[UILabel alloc] initWithFrame:CGRectMake(assetToggleButton.frame.origin.x + assetToggleButton.frame.size.width + 15, 12, 40, 30)];
    topRightLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    topRightLabel.textColor = COLOR_TEXT_DARK_GRAY;
    topRightLabel.text = CURRENCY_SYMBOL_ETH;
    self.rightLabel = topRightLabel;
    [amountView addSubview:topRightLabel];
    
    ContinueButtonInputAccessoryView *inputAccessoryView = [[ContinueButtonInputAccessoryView alloc] init];
    inputAccessoryView.delegate = self;
    self.continuePaymentAccessoryView = inputAccessoryView;
    
    CGFloat leftFieldOriginX = topLeftLabel.frame.origin.x + topLeftLabel.frame.size.width + 8;
    BCSecureTextField *leftField = [self inputTextFieldWithFrame:CGRectMake(leftFieldOriginX, 12, assetToggleButton.frame.origin.x - 8 - leftFieldOriginX, 30)];
    [amountView addSubview:leftField];
    leftField.placeholder = [self assetPlaceholder];
    leftField.inputAccessoryView = inputAccessoryView;
    self.topLeftField = leftField;
    self.btcField = self.topLeftField;
    
    CGFloat rightFieldOriginX = topRightLabel.frame.origin.x + topRightLabel.frame.size.width + 8;
    BCSecureTextField *rightField = [self inputTextFieldWithFrame:CGRectMake(rightFieldOriginX, 12, windowWidth - 8 - rightFieldOriginX, 30)];
    [amountView addSubview:rightField];
    rightField.placeholder = [self assetPlaceholder];
    rightField.inputAccessoryView = inputAccessoryView;
    self.topRightField = rightField;
    self.ethField = self.topRightField;
    
    UIView *dividerLine = [[UIView alloc] initWithFrame:CGRectMake(leftFieldOriginX, leftField.frame.origin.y + leftField.frame.size.height + 12, windowWidth - leftFieldOriginX, 0.5)];
    dividerLine.backgroundColor = COLOR_LINE_GRAY;
    [amountView addSubview:dividerLine];
    
    BCSecureTextField *bottomLeftField = [self inputTextFieldWithFrame:CGRectMake(leftFieldOriginX, dividerLine.frame.origin.y + dividerLine.frame.size.height + 12, leftField.frame.size.width, 30)];
    [amountView addSubview:bottomLeftField];
    bottomLeftField.inputAccessoryView = inputAccessoryView;
    bottomLeftField.placeholder = [self fiatPlaceholder];
    self.bottomLeftField = bottomLeftField;
    
    BCSecureTextField *bottomRightField = [self inputTextFieldWithFrame:CGRectMake(rightFieldOriginX, dividerLine.frame.origin.y + dividerLine.frame.size.height + 12, rightField.frame.size.width, 30)];
    [amountView addSubview:bottomRightField];
    bottomRightField.placeholder = [self fiatPlaceholder];
    bottomRightField.inputAccessoryView = inputAccessoryView;
    self.bottomRightField = bottomRightField;
    
    UILabel *fiatLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 40, 30)];
    fiatLabel.center = CGPointMake(fiatLabel.center.x, bottomLeftField.center.y);
    fiatLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    fiatLabel.textColor = COLOR_TEXT_DARK_GRAY;
    fiatLabel.text = app.latestResponse.symbol_local.code;
    [amountView addSubview:fiatLabel];
    
    self.fiatLabel = fiatLabel;
    
    self.fromToView.fromImageView.image = [UIImage imageNamed:@"chevron_right"];
    self.fromToView.toImageView.image = [UIImage imageNamed:@"chevron_right"];
    
    CGFloat buttonHeight = 50;
    BCLine *lineAboveButtonsView = [[BCLine alloc] initWithYPosition:amountView.frame.origin.y + amountView.frame.size.height];
    [self.view addSubview:lineAboveButtonsView];
    UIView *buttonsView = [[UIView alloc] initWithFrame:CGRectMake(0, amountView.frame.origin.y + amountView.frame.size.height + 0.5, windowWidth, buttonHeight)];
    buttonsView.backgroundColor = COLOR_LINE_GRAY;
    [self.view addSubview:buttonsView];
    
    UIFont *buttonFont = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    CGFloat dividerLineWidth = 0.5;
    UIButton *useMinButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, buttonsView.frame.size.width/2 - dividerLineWidth/2, buttonHeight)];
    useMinButton.titleLabel.font = buttonFont;
    useMinButton.backgroundColor = [UIColor whiteColor];
    [useMinButton setTitleColor:COLOR_BLOCKCHAIN_LIGHT_BLUE forState:UIControlStateNormal];
    [useMinButton setTitle:BC_STRING_USE_MINIMUM forState:UIControlStateNormal];
    [useMinButton addTarget:self action:@selector(useMinButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    [buttonsView addSubview:useMinButton];
    
    CGFloat useMaxButtonOriginX = buttonsView.frame.size.width/2 + dividerLineWidth/2;
    UIButton *useMaxButton = [[UIButton alloc] initWithFrame:CGRectMake(useMaxButtonOriginX, 0, buttonsView.frame.size.width - useMaxButtonOriginX, buttonHeight)];
    useMaxButton.titleLabel.font = buttonFont;
    useMaxButton.backgroundColor = [UIColor whiteColor];
    [useMaxButton setTitleColor:COLOR_BLOCKCHAIN_LIGHT_BLUE forState:UIControlStateNormal];
    [useMaxButton setTitle:BC_STRING_USE_MAXIMUM forState:UIControlStateNormal];
    [useMaxButton addTarget:self action:@selector(useMaxButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    [buttonsView addSubview:useMaxButton];
    
    UITextView *errorTextView = [[UITextView alloc] initWithFrame:CGRectMake(15, buttonsView.frame.origin.y + buttonsView.frame.size.height + 8, windowWidth - 30, 30)];
    errorTextView.editable = NO;
    errorTextView.scrollEnabled = NO;
    errorTextView.selectable = NO;
    errorTextView.textColor = COLOR_WARNING_RED;
    errorTextView.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    errorTextView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:errorTextView];
    errorTextView.hidden = YES;
    self.errorTextView = errorTextView;
    
    UIButton *continueButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width - 40, BUTTON_HEIGHT)];
    continueButton.backgroundColor = COLOR_BLOCKCHAIN_LIGHT_BLUE;
    continueButton.layer.cornerRadius = CORNER_RADIUS_BUTTON;
    [continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    continueButton.titleLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:17.0];
    [continueButton setTitle:BC_STRING_CONTINUE forState:UIControlStateNormal];
    continueButton.center = CGPointMake(self.view.center.x, self.view.frame.size.height - 8 - BUTTON_HEIGHT/2);
    [self.view addSubview:continueButton];
    [continueButton addTarget:self action:@selector(continueButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    self.continueButton = continueButton;
}

#pragma mark - JS Callbacks

- (void)didGetExchangeRate:(NSDictionary *)result
{
    [self enableAssetToggleButton];
    [self.spinner stopAnimating];
    
    if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
        NSString *minNumberString = [result objectForKey:DICTIONARY_KEY_TRADE_MINIMUM];
        self.minimum = [NSNumber numberWithLongLong:[NSNumberFormatter parseBtcValueFromString:minNumberString]];
        NSString *maxNumberString = [result objectForKey:DICTIONARY_KEY_TRADE_MAX_LIMIT];
        self.maximum = [NSNumber numberWithLongLong:[NSNumberFormatter parseBtcValueFromString:maxNumberString]];
        NSString *hardLimitString = [result objectForKey:DICTIONARY_KEY_BTC_HARD_LIMIT];
        self.maximumHardLimit = [NSNumber numberWithLongLong:[NSNumberFormatter parseBtcValueFromString:hardLimitString]];
        [app.wallet getAvailableBtcBalanceForAccount:self.btcAccount];
    } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
        self.minimum = [NSDecimalNumber decimalNumberWithString:[result objectForKey:DICTIONARY_KEY_TRADE_MINIMUM]];
        self.maximum = [NSDecimalNumber decimalNumberWithString:[result objectForKey:DICTIONARY_KEY_TRADE_MAX_LIMIT]];
        self.maximumHardLimit = [NSDecimalNumber decimalNumberWithString:[result objectForKey:DICTIONARY_KEY_ETH_HARD_LIMIT]];
        [app.wallet getAvailableEthBalance];
    }
}

- (void)didGetAvailableEthBalance:(NSDictionary *)result
{
    self.availableBalance = [NSDecimalNumber decimalNumberWithDecimal:[[result objectForKey:DICTIONARY_KEY_AMOUNT] decimalValue]];
    self.fee = [result objectForKey:DICTIONARY_KEY_FEE];
    
    if ([self.availableBalance compare:@0] == NSOrderedSame ||
        [self.availableBalance compare:@0] == NSOrderedAscending) {
        [app showGetAssetsAlert];
    }
    
    [self updateAvailableBalance];
}

- (void)didGetAvailableBtcBalance:(NSDictionary *)result
{
    self.availableBalance = [result objectForKey:DICTIONARY_KEY_AMOUNT];
    self.fee = [result objectForKey:DICTIONARY_KEY_FEE];
    
    [self updateAvailableBalance];
}

- (void)updateAvailableBalance
{
    BOOL overAvailable = NO;
    BOOL overMax = NO;
    BOOL underMin = NO;
    BOOL zeroAmount = NO;
    
    NSString *errorText;
    
    if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
        
        uint64_t amount = [self.amount longLongValue];
        
        DLog(@"btc amount: %lld", amount);
        DLog(@"available: %lld", [self.availableBalance longLongValue]);
        DLog(@"max: %lld", [self.maximum longLongValue])
        
        if (amount == 0) {
            zeroAmount = YES;
        } else if (amount > [self.availableBalance longLongValue]) {
            DLog(@"btc over available");
            overAvailable = YES;
            errorText = BC_STRING_NOT_ENOUGH_TO_EXCHANGE;
        } else if (amount > [self.maximum longLongValue] || amount > [self.maximumHardLimit longLongValue]) {
            DLog(@"btc over max");
            overMax = YES;
            errorText = BC_STRING_ABOVE_MAXIMUM_LIMIT;
        } else if (amount < [self.minimum longLongValue] ) {
            DLog(@"btc under min");
            underMin = YES;
            errorText = BC_STRING_BELOW_MINIMUM_LIMIT;
        }
        
    } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
        DLog(@"eth amount: %@", [self.amount stringValue]);
        DLog(@"available: %@", [self.availableBalance stringValue]);
        DLog(@"max: %@", [self.maximum stringValue])
        
        if ([self.amount compare:@0] == NSOrderedSame || !self.amount) {
            zeroAmount = YES;
        } else if ([self.amount compare:self.availableBalance] == NSOrderedDescending) {
            DLog(@"eth over available");
            overAvailable = YES;
            errorText = BC_STRING_NOT_ENOUGH_TO_EXCHANGE;
        } else if ([self.amount compare:self.maximum] == NSOrderedDescending || [self.amount compare:self.maximumHardLimit] == NSOrderedDescending) {
            DLog(@"eth over max");
            overMax = YES;
            errorText = BC_STRING_ABOVE_MAXIMUM_LIMIT;
        } else if ([self.amount compare:self.minimum] == NSOrderedAscending) {
            DLog(@"eth under min");
            underMin = YES;
            errorText = BC_STRING_BELOW_MINIMUM_LIMIT;
        }
    }
    
    if (zeroAmount) {
        self.errorTextView.hidden = YES;
        [self disablePaymentButtons];
    } else if (overAvailable || overMax || underMin) {
        [self highlightInvalidAmounts];
        self.errorTextView.hidden = NO;
        self.errorTextView.text = errorText;
        [self disablePaymentButtons];
    } else {
        [self removeHighlightFromAmounts];
        [self enablePaymentButtons];
        self.errorTextView.hidden = YES;
    }
}

- (void)enablePaymentButtons
{
    [self.continuePaymentAccessoryView enableContinueButton];
    
    self.continueButton.enabled = YES;
    [self.continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.continueButton setBackgroundColor:COLOR_BLOCKCHAIN_LIGHT_BLUE];
}

- (void)disablePaymentButtons
{
    [self.continuePaymentAccessoryView disableContinueButton];

    self.continueButton.enabled = NO;
    [self.continueButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [self.continueButton setBackgroundColor:COLOR_BUTTON_KEYPAD_GRAY];
}

- (void)didGetQuote:(NSDictionary *)result
{
    
}

- (void)didGetApproximateQuote:(NSDictionary *)result
{
    id depositAmount = [result objectForKey:DICTIONARY_KEY_DEPOSIT_AMOUNT];
    id withdrawalAmount = [result objectForKey:DICTIONARY_KEY_WITHDRAWAL_AMOUNT];
    
    self.topLeftField.text = [depositAmount isKindOfClass:[NSString class]] ? depositAmount : [depositAmount stringValue];
    self.topRightField.text = [withdrawalAmount isKindOfClass:[NSString class]] ? withdrawalAmount : [withdrawalAmount stringValue];
    
    NSString *pair = [self coinPair];
    if ([[pair lowercaseString] isEqualToString: [[result objectForKey:DICTIONARY_KEY_PAIR] lowercaseString]]) {
        
        NSString *btcResult = [self convertBtcAmountToFiat:self.btcField.text];
        NSString *ethResult = [self convertEthAmountToFiat:self.ethField.text];
        
        if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
            self.bottomRightField.text = btcResult;
            self.bottomLeftField.text = ethResult;
        } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
            self.bottomLeftField.text = btcResult;
            self.bottomRightField.text = ethResult;
        }
        
        [self updateAvailableBalance];
    } else {
        DLog(@"Wrong coinpair!");
    }
}

- (void)didBuildExchangeTrade:(NSDictionary *)tradeInfo
{
    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    [navigationController hideBusyView];
    
    ExchangeTrade *trade = [ExchangeTrade builtTradeFromJSONDict:tradeInfo];
    // pair is not returned from API call - need to manually set
    trade.pair = [self coinPair];
    trade.exchangeRateString = [trade exchangeRateString];
    NSString *feeString = [NSNumberFormatter convertedDecimalString:[tradeInfo objectForKey:DICTIONARY_KEY_FEE]];
    trade.transactionFee = [NSDecimalNumber decimalNumberWithString:feeString];
    ExchangeConfirmViewController *confirmViewController = [[ExchangeConfirmViewController alloc] initWithExchangeTrade:trade];
    [self.navigationController pushViewController:confirmViewController animated:YES];
}

#pragma mark - Conversion

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSArray  *points = [newString componentsSeparatedByString:@"."];
    NSLocale *locale = [textField.textInputMode.primaryLanguage isEqualToString:LOCALE_IDENTIFIER_AR] ? [NSLocale localeWithLocaleIdentifier:textField.textInputMode.primaryLanguage] : [NSLocale currentLocale];
    NSArray  *commas = [newString componentsSeparatedByString:[locale objectForKey:NSLocaleDecimalSeparator]];
    
    // Only one comma or point in input field allowed
    if ([points count] > 2 || [commas count] > 2)
        return NO;
    
    // Only 1 leading zero
    if (points.count == 1 || commas.count == 1) {
        if (range.location == 1 && ![string isEqualToString:@"."] && ![string isEqualToString:@","] && ![string isEqualToString:@"٫"] && [textField.text isEqualToString:@"0"]) {
            return NO;
        }
    }
    
    // When entering amount in ETH, max 18 decimal places
    if (textField == self.ethField) {
        // Max number of decimal places depends on bitcoin unit
        NSUInteger maxlength = ETH_DECIMAL_LIMIT;
        
        if (points.count == 2) {
            NSString *decimalString = points[1];
            if (decimalString.length > maxlength) {
                return NO;
            }
        }
        else if (commas.count == 2) {
            NSString *decimalString = commas[1];
            if (decimalString.length > maxlength) {
                return NO;
            }
        }
    }
    
    // When entering amount in BTC, max 8 decimal places
    else if (textField == self.btcField) {
        // Max number of decimal places depends on bitcoin unit
        NSUInteger maxlength = [@(SATOSHI) stringValue].length - [@(SATOSHI / app.latestResponse.symbol_btc.conversion) stringValue].length;
        
        if (points.count == 2) {
            NSString *decimalString = points[1];
            if (decimalString.length > maxlength) {
                return NO;
            }
        }
        else if (commas.count == 2) {
            NSString *decimalString = commas[1];
            if (decimalString.length > maxlength) {
                return NO;
            }
        }
    }
    
    // Fiat currencies have a max of 3 decimal places, most of them actually only 2. For now we will use 2.
    else if (textField == self.bottomLeftField || self.bottomRightField) {
        if (points.count == 2) {
            NSString *decimalString = points[1];
            if (decimalString.length > 2) {
                return NO;
            }
        }
        else if (commas.count == 2) {
            NSString *decimalString = commas[1];
            if (decimalString.length > 2) {
                return NO;
            }
        }
    }
    
    NSString *amountString = [newString stringByReplacingOccurrencesOfString:@"," withString:@"."];
    if (![amountString containsString:@"."]) {
        amountString = [newString stringByReplacingOccurrencesOfString:@"٫" withString:@"."];
    }
    
    [self saveAmount:amountString fromField:textField];
    
    [self performSelector:@selector(doCurrencyConversionAfterTyping) withObject:nil afterDelay:0.1f];
    return YES;
}

- (void)saveAmount:(NSString *)amountString fromField:(UITextField *)textField
{
    if (textField == self.ethField) {
        self.amount = [NSDecimalNumber decimalNumberWithString:amountString];
    } else if (textField == self.btcField) {
        self.amount = [NSNumber numberWithLongLong:[NSNumberFormatter parseBtcValueFromString:amountString]];
    } else {
        if (textField == self.bottomLeftField) {
            if (self.topLeftField == self.ethField) {
                [self convertFiatStringToEth:amountString];
            } else if (self.topLeftField == self.btcField) {
                [self convertFiatStringToBtc:amountString];
            }
        } else if (textField == self.bottomRightField) {
            if (self.topRightField == self.ethField) {
                [self convertFiatStringToEth:amountString];
            } else if (self.topRightField == self.btcField) {
                [self convertFiatStringToBtc:amountString];
            }
        }
    }
}

- (void)convertFiatStringToEth:(NSString *)amountString
{
    NSDecimalNumber *amountStringDecimalNumber = amountString && [amountString doubleValue] > 0 ? [NSDecimalNumber decimalNumberWithString:amountString] : 0;
    self.amount = [NSNumberFormatter convertFiatToEth:amountStringDecimalNumber exchangeRate:app.wallet.latestEthExchangeRate];
}

- (void)convertFiatStringToBtc:(NSString *)amountString
{
    self.amount = [NSNumber numberWithLongLong:app.latestResponse.symbol_local.conversion * [amountString doubleValue]];
}

- (NSString *)convertBtcAmountToFiat
{
    return [self convertBtcAmountToFiat:self.amount];
}

- (NSString *)convertEthAmountToFiat
{
    return [self convertEthAmountToFiat:self.amount];
}

- (NSString *)convertBtcAmountToFiat:(id)amount
{
    uint64_t amountArg = 0;
    if ([amount isKindOfClass:[NSString class]]) {
        amountArg = [NSNumberFormatter parseBtcValueFromString:amount];
    } else if ([amount isKindOfClass:[NSNumber class]])  {
        amountArg = [amount longLongValue];
    } else {
        DLog(@"Amount is not a string or number!");
    }
    
    return [NSNumberFormatter formatAmount:amountArg localCurrency:YES];
}

- (NSString *)convertEthAmountToFiat:(id)amount
{
    id amountArg;
    if ([amount isKindOfClass:[NSString class]]) {
        amountArg = amount;
    } else if ([amount isKindOfClass:[NSNumber class]])  {
        amountArg = [amount stringValue];
    } else {
        DLog(@"Amount is not a string or number!");
    }
    
    app.localCurrencyFormatter.usesGroupingSeparator = NO;
    NSString *result = [NSNumberFormatter formatEthToFiat:amountArg exchangeRate:app.wallet.latestEthExchangeRate];
    app.localCurrencyFormatter.usesGroupingSeparator = YES;
    return result;
}

- (void)doCurrencyConversionAfterTyping
{
    [self doCurrencyConversion];
    
    [self updateAvailableBalance];
    
    [self performSelector:@selector(getApproximateQuote) withObject:nil afterDelay:0.5];
}

- (void)doCurrencyConversion
{
    if ([self.btcField isFirstResponder]) {
        
        NSString *result = [self convertBtcAmountToFiat];
        
        if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
            self.bottomRightField.text = result;
        } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
            self.bottomLeftField.text = result;
        }
        
    } else if ([self.ethField isFirstResponder]) {
        
        NSString *result = [self convertEthAmountToFiat];

        if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
            self.bottomLeftField.text = result;
        } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
            self.bottomRightField.text = result;
        }
        
    } else if ([self.bottomLeftField isFirstResponder] || [self.bottomRightField isFirstResponder]) {
        
        NSString *ethString = [self.amount stringValue];
        NSString *btcString = [NSNumberFormatter satoshiToBTC:[self.amount longLongValue]];
        
        if ([self.bottomLeftField isFirstResponder]) {
            if (self.topLeftField == self.ethField) {
                self.ethField.text = ethString;
            } else if (self.topLeftField == self.btcField) {
                self.btcField.text = btcString;
            }
        } else if ([self.bottomRightField isFirstResponder]) {
            if (self.topRightField == self.ethField) {
                self.ethField.text = ethString;
            } else if (self.topRightField == self.btcField) {
                self.btcField.text = btcString;
            }
        }
    }
}

#pragma mark - Gesture Actions

- (void)assetToggleButtonClicked
{
    if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
        [self selectFromEther];
        [self selectToBitcoin];
    } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
        [self selectFromBitcoin];
        [self selectToEther];
    }
    
    [self getRate];
}

- (void)fromButtonClicked
{
    [self selectAccountClicked:SelectModeExchangeAccountFrom];
}

- (void)toButtonClicked
{
    [self selectAccountClicked:SelectModeExchangeAccountTo];
}

- (void)selectAccountClicked:(SelectMode)selectMode
{
    BCAddressSelectionView *selectorView = [[BCAddressSelectionView alloc] initWithWallet:app.wallet selectMode:selectMode];
    selectorView.delegate = self;
    selectorView.frame = CGRectMake(0, DEFAULT_HEADER_HEIGHT, self.view.frame.size.width, self.view.frame.size.height);
    
    UIViewController *viewController = [UIViewController new];
    viewController.automaticallyAdjustsScrollViewInsets = NO;
    [viewController.view addSubview:selectorView];
    
    [self.navigationController pushViewController:viewController animated:YES];
    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    navigationController.headerTitle = selectMode == SelectModeExchangeAccountTo ? BC_STRING_TO : BC_STRING_FROM;
}

- (void)useMinButtonClicked
{
    [self autoFillFromAmount:self.minimum];
}

- (void)useMaxButtonClicked
{
    id maxAmount = [self.availableBalance compare:self.maximum] == NSOrderedAscending ? self.availableBalance : self.maximum;
    [self autoFillFromAmount:maxAmount];
}

#pragma mark - View actions

- (void)selectFromEther
{
    self.fromSymbol = CURRENCY_SYMBOL_ETH;
    self.ethField = self.topLeftField;
    self.fromToView.fromLabel.text = BC_STRING_ETHER;
    self.leftLabel.text = CURRENCY_SYMBOL_ETH;
    self.fromAddress = [app.wallet getEtherAddress];
}

- (void)selectFromBitcoin
{
    self.fromSymbol = CURRENCY_SYMBOL_BTC;
    self.btcField = self.topLeftField;
    self.fromToView.fromLabel.text = [self bitcoinLabelText];
    self.leftLabel.text = CURRENCY_SYMBOL_BTC;
    self.fromAddress = [app.wallet getReceiveAddressForAccount:self.btcAccount];
}

- (void)selectToEther
{
    self.toSymbol = CURRENCY_SYMBOL_ETH;
    self.ethField = self.topRightField;
    self.fromToView.toLabel.text = BC_STRING_ETHER;
    self.rightLabel.text = CURRENCY_SYMBOL_ETH;
    self.toAddress = [app.wallet getEtherAddress];
}

- (void)selectToBitcoin
{
    self.toSymbol = CURRENCY_SYMBOL_BTC;
    self.btcField = self.topRightField;
    self.fromToView.toLabel.text = [self bitcoinLabelText];
    self.rightLabel.text = CURRENCY_SYMBOL_BTC;
    self.toAddress = [app.wallet getReceiveAddressForAccount:self.btcAccount];
}

- (void)autoFillFromAmount:(id)amount
{
    NSString *amountString = [self amountString:amount];
    self.topLeftField.text = amountString;
    [self saveAmount:amountString fromField:self.topLeftField];
    
    NSString *fiatResult;
    if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_ETH]) {
        fiatResult = [self convertEthAmountToFiat];
    } else if ([self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC]) {
        fiatResult = [self convertBtcAmountToFiat];
    }
    self.bottomLeftField.text = fiatResult;
    
    [self updateAvailableBalance];
    
    [self hideKeyboard];
    
    [self performSelector:@selector(getApproximateQuote) withObject:nil afterDelay:0.5];
}

#pragma mark - Wallet actions

- (void)getRate
{
    [self disableAssetToggleButton];
    [self.spinner startAnimating];
    
    [app.wallet getRate:[self coinPair]];
}

- (void)getQuote
{
    [app.wallet getQuote:[self coinPair] amount:@"0.1"];
}

- (void)getApproximateQuote
{
    [self disablePaymentButtons];
    
    if (self.currentDataTask) {
        [self.currentDataTask cancel];
        self.currentDataTask = nil;
        [self.spinner stopAnimating];
    }
    
    BOOL usingFromField = ![self.topRightField isFirstResponder] && ![self.bottomRightField isFirstResponder];

    NSString *amount;
    if ([self hasAmountGreaterThanZero:self.amount]) {

        [self disableAssetToggleButton];
        [self.spinner startAnimating];
        
        amount = [self amountString:self.amount];
        
        self.currentDataTask = [app.wallet getApproximateQuote:[self coinPair] usingFromField:usingFromField amount:amount completion:^(NSDictionary *result, NSURLResponse *response, NSError *error) {
            DLog(@"approximate quote result: %@", result);
            
            [self enableAssetToggleButton];
            [self.spinner stopAnimating];
            
            NSDictionary *resultSuccess = [result objectForKey:DICTIONARY_KEY_SUCCESS];
            if (resultSuccess) {
                [self didGetApproximateQuote:resultSuccess];
            } else {
                DLog(@"Error getting approximate quote:%@", error);
            }
        }];
    }
}

- (void)buildTrade
{
    BOOL fromBtc = [self.fromSymbol isEqualToString:CURRENCY_SYMBOL_BTC];
    int fromAccount = fromBtc ? self.btcAccount : 0;
    int toAccount = fromBtc ? self.btcAccount : 0;
    NSString *fee = fromBtc ? [NSString stringWithFormat:@"%lld", [self.fee longLongValue]] : [self amountString:self.fee];
    
    [app.wallet buildExchangeTradeFromAccount:fromAccount toAccount:toAccount coinPair:[self coinPair] amount:[self amountString:self.amount] fee:fee];
}

#pragma mark - Helpers

- (void)hideKeyboard
{
    [self.bottomRightField resignFirstResponder];
    [self.bottomLeftField resignFirstResponder];
    [self.topLeftField resignFirstResponder];
    [self.topRightField resignFirstResponder];
}

- (void)highlightInvalidAmounts
{
    UIColor *newColor = COLOR_WARNING_RED;
    self.topLeftField.textColor = newColor;
    self.topRightField.textColor = newColor;
    self.bottomLeftField.textColor = newColor;
    self.bottomRightField.textColor = newColor;
}

- (void)removeHighlightFromAmounts
{
    UIColor *newColor = COLOR_TEXT_DARK_GRAY;
    self.topLeftField.textColor = newColor;
    self.topRightField.textColor = newColor;
    self.bottomLeftField.textColor = newColor;
    self.bottomRightField.textColor = newColor;
}

- (BOOL)hasAmountGreaterThanZero:(id)amount
{
    if ([amount isMemberOfClass:[NSDecimalNumber class]]) {
        return [amount compare:@0] == NSOrderedDescending;
    } else if ([amount respondsToSelector:@selector(longLongValue)]) {
        return [amount longLongValue] > 0;
    } else if (!amount) {
        DLog(@"Nil amount saved");
        return NO;
    } else {
        DLog(@"Error: unknown class for amount: %@", [self.amount class]);
        return NO;
    }
}

- (NSString *)amountString:(id)amount
{
    NSString *amountString;
    if ([self hasAmountGreaterThanZero:amount]) {
        if ([amount isMemberOfClass:[NSDecimalNumber class]]) {
            amountString = [amount stringValue];
        } else if ([amount respondsToSelector:@selector(longLongValue)]) {
            amountString = [NSNumberFormatter satoshiToBTC:[amount longLongValue]];
        } else {
            DLog(@"Error: unknown class for amount: %@", [amount class]);
        }
    }
    
    return amountString;
}

- (BCSecureTextField *)inputTextFieldWithFrame:(CGRect)frame
{
    BCSecureTextField *textField = [[BCSecureTextField alloc] initWithFrame:frame];
    textField.keyboardType = UIKeyboardTypeDecimalPad;
    textField.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    textField.textColor = COLOR_TEXT_DARK_GRAY;
    textField.delegate = self;
    return textField;
}

- (NSString *)coinPair
{
    return [NSString stringWithFormat:@"%@_%@", self.fromSymbol, self.toSymbol];
}

- (void)enableAssetToggleButton
{
    self.assetToggleButton.userInteractionEnabled = YES;
    [self.assetToggleButton setImage:[UIImage imageNamed:IMAGE_NAME_SWITCH_CURRENCIES] forState:UIControlStateNormal];
}

- (void)disableAssetToggleButton
{
    self.assetToggleButton.userInteractionEnabled = NO;
    [self.assetToggleButton setImage:nil forState:UIControlStateNormal];
}

- (NSString *)fiatPlaceholder
{
    return [NSString stringWithFormat:FIAT_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];;
}

- (NSString *)assetPlaceholder
{
    return [NSString stringWithFormat:BTC_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
}

- (NSString *)bitcoinLabelText
{
    return [app.wallet getActiveAccountsCount] > 1 ? [app.wallet getLabelForAccount:self.btcAccount] : BC_STRING_BITCOIN;
}

#pragma mark - Address Selection Delegate

- (void)didSelectFromEthAccount
{
    [self.navigationController popViewControllerAnimated:YES];
    
    [self selectFromEther];
    [self selectToBitcoin];
    
    self.fromToView.fromLabel.text = [app.wallet getLabelForEthAccount];
    self.fromToView.toLabel.text = [self bitcoinLabelText];
    
    [self getRate];
}

- (void)didSelectToEthAccount
{
    [self.navigationController popViewControllerAnimated:YES];
    
    [self selectFromBitcoin];
    [self selectToEther];
    
    self.fromToView.fromLabel.text = [self bitcoinLabelText];
    self.fromToView.toLabel.text = [app.wallet getLabelForEthAccount];
    
    [self getRate];
}

- (void)didSelectFromAccount:(int)account
{
    [self.navigationController popViewControllerAnimated:YES];
    
    self.btcAccount = account;
    
    [self selectFromBitcoin];
    [self selectToEther];
    
    self.fromToView.fromLabel.text = [self bitcoinLabelText];
    self.fromToView.toLabel.text = [app.wallet getLabelForEthAccount];
    
    [self getRate];
}

- (void)didSelectToAccount:(int)account
{
    [self.navigationController popViewControllerAnimated:YES];
    
    self.btcAccount = account;
    
    [self selectFromEther];
    [self selectToBitcoin];
    
    self.fromToView.fromLabel.text = [app.wallet getLabelForEthAccount];
    self.fromToView.toLabel.text = [self bitcoinLabelText];
    
    [self getRate];
}

- (void)didSelectToAddress:(NSString *)address
{
    // required by protocol
}

- (void)didSelectContact:(Contact *)contact
{
    // required by protocol
}

- (void)didSelectFromAddress:(NSString *)address
{
    // required by protocol
}

#pragma mark - Continue Button Input Accessory View Delegate

- (void)continueButtonClicked
{
    [self hideKeyboard];
    
    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    [navigationController showBusyViewWithLoadingText:BC_STRING_GETTING_QUOTE];
    
    [self performSelector:@selector(buildTrade) withObject:nil afterDelay:DELAY_KEYBOARD_DISMISSAL];
}

- (void)closeButtonClicked
{
    [self.topLeftField resignFirstResponder];
    [self.topRightField resignFirstResponder];
    [self.bottomLeftField resignFirstResponder];
    [self.bottomRightField resignFirstResponder];
}

@end
