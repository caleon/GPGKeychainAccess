/*
 Copyright © Roman Zechmeister, 2010
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "SheetController.h"
#import "ActionController.h"
#import "KeychainController.h"
#import "KeyInfo.h";
#import <AddressBook/AddressBook.h>

@implementation SheetController

static SheetController *_sharedInstance = nil;

@synthesize myKeyInfo;
@synthesize myString;
@synthesize mySubkey;

@synthesize msgText;
@synthesize pattern;
@synthesize name;
@synthesize email;
@synthesize comment;
@synthesize availableLengths;
@synthesize length;
@synthesize hasExpirationDate;
@synthesize expirationDate;
@synthesize minExpirationDate;
@synthesize maxExpirationDate;
@synthesize sigType;
@synthesize localSig;
@synthesize emailAddresses;
@synthesize secretKeys;
@synthesize secretKeyFingerprints;
@synthesize secretKeyId;



+ (id)sharedInstance {
	if (_sharedInstance == nil) {
		_sharedInstance = [[self alloc] init];
	}
	return _sharedInstance;
}

- (id)init {
	if (self = [super init]) {
		[NSBundle loadNibNamed:@"ModalSheets" owner:self];
	}
	return self;
}


- (void)addSubkey:(KeyInfo *)keyInfo {
	self.msgText = [NSString stringWithFormat:localized(@"GenerateSubkey_Msg"), [keyInfo userID], [keyInfo shortKeyID]];
	self.length = 2048;
	self.keyType = 3;
	[self setStandardExpirationDates];
	self.hasExpirationDate = NO;	

	
	self.myKeyInfo = keyInfo;
	currentAction = AddSubkeyAction;
	self.displayedView = generateSubkeyView;
	
	[self runSheetForWindow:inspectorWindow];
}
- (void)addSubkey_Action {
	[actionController addSubkeyForKeyInfo:myKeyInfo type:keyType length:length daysToExpire:hasExpirationDate ? getDaysToExpire (expirationDate) : 0];
	[self closeSheet];
}

- (void)addUserID:(KeyInfo *)keyInfo {
	self.msgText = [NSString stringWithFormat:localized(@"GenerateUserID_Msg"), [keyInfo userID], [keyInfo shortKeyID]];
	
	[self setDataFromAddressBook];
	self.comment = @"";

	
	self.myKeyInfo = keyInfo;
	currentAction = AddUserIDAction;
	self.displayedView = generateUserIDView;
	
	[self runSheetForWindow:inspectorWindow];	
}
- (void)addUserID_Action {
	[actionController addUserIDForKeyInfo:myKeyInfo name:name email:email comment:comment];
	[self closeSheet];
}

- (void)addSignature:(KeyInfo *)keyInfo userID:(NSString *)userID {
	self.msgText = [NSString stringWithFormat:localized(userID ? @"GenerateUidSignature_Msg" : @"GenerateSignature_Msg"), [keyInfo userID], [keyInfo shortKeyID]];
	self.sigType = 0;
	self.localSig = NO;
	[self setStandardExpirationDates];
	self.hasExpirationDate = NO;
	
	
	NSArray *defaultKeys = [[gpgContext options] activeOptionValuesForName:@"default-key"];
	NSString *defaultKey;
	if ([defaultKeys count] > 0) {
		defaultKey = [defaultKeys objectAtIndex:0];
		switch ([defaultKey length]) {
			case 9:
			case 17:
			case 33:
			case 41:
				if ([defaultKey hasPrefix:@"0"]) {
					defaultKey = [defaultKey substringFromIndex:1];
				}
				break;
			case 10:
			case 18:
			case 34:
			case 42:
				if ([defaultKey hasPrefix:@"0x"]) {
					defaultKey = [defaultKey substringFromIndex:2];
				}
				break;
		}
	} else {
		defaultKey = nil;
	}

	self.secretKeyId = 0;
	
	NSSet *secKeySet = [keychainController secretKeys];
	NSMutableArray *secKeys = [NSMutableArray arrayWithCapacity:[secKeySet count]];
	NSMutableArray *fingerprints = [NSMutableArray arrayWithCapacity:[secKeySet count]];
	KeyInfo *aKeyInfo;
	NSDictionary *keychain = [keychainController keychain];
	int i = 0;
	
	for (NSString *fingerprint in secKeySet) {
		aKeyInfo = [keychain objectForKey:fingerprint];
		if (defaultKey && [aKeyInfo.textForFilter rangeOfString:defaultKey].length != 0) {
			self.secretKeyId = i;
			defaultKey = nil;
		}
		[secKeys addObject:[NSString stringWithFormat:@"%@, %@", aKeyInfo.shortKeyID, aKeyInfo.userID]];
		[fingerprints addObject:fingerprint];
		i++;
	}
	self.secretKeys = secKeys;
	self.secretKeyFingerprints = fingerprints;

	
	
	self.myKeyInfo = keyInfo;
	self.myString = userID;
	currentAction = AddSignatureAction;
	self.displayedView = generateSignatureView;
	
	[self runSheetForWindow:userID ? inspectorWindow : mainWindow];
}
- (void)addSignature_Action {
	[actionController addSignatureForKeyInfo:myKeyInfo andUserID:myString signKey:[secretKeyFingerprints objectAtIndex:secretKeyId] type:sigType local:localSig daysToExpire:hasExpirationDate ? getDaysToExpire (expirationDate) : 0];
	[self closeSheet];
}

- (void)changeExpirationDate:(KeyInfo *)keyInfo subkey:(KeyInfo_Subkey *)subkey {
	NSDate *aDate;
	if (subkey) {
		self.msgText = [NSString stringWithFormat:localized(@"ChangeSubkeyExpirationDate_Msg"), [keyInfo userID], [keyInfo shortKeyID], [subkey shortKeyID]];
		aDate = [subkey expirationDate];
	} else {
		self.msgText = [NSString stringWithFormat:localized(@"ChangeExpirationDate_Msg"), [keyInfo userID], [keyInfo shortKeyID]];
		aDate = [keyInfo expirationDate];		
	}	

	[self setStandardExpirationDates];
	if (aDate) {
		self.hasExpirationDate = YES;
		self.expirationDate = aDate;
		self.minExpirationDate = [self.minExpirationDate earlierDate:aDate];			
	} else {
		self.hasExpirationDate = NO;
	}
	
	
	self.myKeyInfo = keyInfo;
	self.mySubkey = subkey;
	currentAction = ChangeExpirationDateAction;
	self.displayedView = changeExpirationDateView;
	
	[self runSheetForWindow:inspectorWindow];	
}
- (void)changeExpirationDate_Action {
	[actionController changeExpirationDateForKeyInfo:myKeyInfo subkey:mySubkey daysToExpire:hasExpirationDate ? getDaysToExpire (expirationDate) : 0];
	[self closeSheet];
}

- (void)searchKeys {
	self.pattern = @"";
	
	currentAction = SearchKeysAction;
	self.displayedView = searchKeysView;
	
	[self runSheetForWindow:mainWindow];		
}
- (void)searchKeys_Action {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self performSelectorOnMainThread:@selector(showFoundKeysWithText:) withObject:[actionController searchKeysWithPattern:pattern] waitUntilDone:NO];
	[pool drain];
}
- (void)showFoundKeysWithText:(NSString *)text {	
	self.msgText = text;
	self.displayedView = foundKeysView;
}


- (void)receiveKeys {
	self.pattern = @"";
	
	currentAction = ReceiveKeysAction;
	self.displayedView = receiveKeysView;
	
	[self runSheetForWindow:mainWindow];		
}
- (void)receiveKeys_Action {
	[actionController receiveKeysWithPattern:pattern];
	[self closeSheet];
}


- (void)generateNewKey {
	self.length = 2048;
	self.keyType = 1;
	[self setStandardExpirationDates];
	self.hasExpirationDate = NO;
	
	[self setDataFromAddressBook];
	self.comment = @"";
	
	currentAction = NewKeyAction;
	self.displayedView = newKeyView;
	
	[self runSheetForWindow:mainWindow];
}


- (void)newKey_Action {
	[actionController generateNewKeyWithName:name email:email comment:comment type:keyType length:length daysToExpire:hasExpirationDate ? getDaysToExpire (expirationDate) : 0];
	[self closeSheet];
}


- (void)closeSheet {
	[self performSelectorOnMainThread:@selector(cancelButton:) withObject:nil waitUntilDone:NO];
}

- (IBAction)okButton:(id)sender {
	[sheetWindow endEditingFor:nil];
	switch (currentAction) {
		case NewKeyAction:
			if (![self checkName]) return;
			if (![self checkEmailMustSet:YES]) return;
			if (![self checkComment]) return;

			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(newKey_Action) toTarget:self withObject:nil];
			break;
		case AddSubkeyAction:
			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(addSubkey_Action) toTarget:self withObject:nil];
			break;
		case AddUserIDAction:
			if (![self checkName]) return;
			if (![self checkEmailMustSet:NO]) return;
			if (![self checkComment]) return;
	
			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(addUserID_Action) toTarget:self withObject:nil];			
			break;
		case AddSignatureAction:
			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(addSignature_Action) toTarget:self withObject:nil];
			break;
		case ChangeExpirationDateAction:
			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(changeExpirationDate_Action) toTarget:self withObject:nil];
			break;
		case SearchKeysAction:
			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(searchKeys_Action) toTarget:self withObject:nil];
			break;
		case ReceiveKeysAction:
			self.displayedView = progressView;
			[NSThread detachNewThreadSelector:@selector(receiveKeys_Action) toTarget:self withObject:nil];
			break;
			
	}
}
- (IBAction)cancelButton:(id)sender {
	self.myKeyInfo = nil;
	self.mySubkey = nil;
	self.myString = nil;
	[sheetWindow orderOut:self];
	[NSApp stopModal];
}
- (IBAction)backButton:(id)sender {
	switch (currentAction) {
	}
}

- (void)runSheetForWindow:(NSWindow *)window {
	[NSApp beginSheet:sheetWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[NSApp runModalForWindow:sheetWindow];
	[NSApp endSheet:sheetWindow];
	
	self.displayedView = nil;
}


- (void)setStandardExpirationDates {
	//Setzt minExpirationDate einen Tag in die Zukunft.
	//Setzt maxExpirationDate 500 Jahre in die Zukunft.
	//Setzt expirationDate ein Jahr in die Zukunft.	
	
	NSDateComponents *dateComponents = [[[NSDateComponents alloc] init] autorelease];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *curDate = [NSDate date];
	[dateComponents setDay:1];
	self.minExpirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0];
	[dateComponents setDay:0];
	[dateComponents setYear:10];
	self.expirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0]; 	
	[dateComponents setYear:500];
	self.maxExpirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0]; 	
}
- (void)setDataFromAddressBook {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ABPerson *myPerson = [[ABAddressBook sharedAddressBook] me];
	if (myPerson) {
		NSString *abFirstName = [myPerson valueForProperty:kABFirstNameProperty];
		NSString *abLastName = [myPerson valueForProperty:kABLastNameProperty];
		
		if (abFirstName && abLastName) {
			self.name = [NSString stringWithFormat:@"%@ %@", abFirstName, abLastName];
		} else if (abFirstName) {
			self.name = abFirstName;
		} else if (abLastName) {
			self.name = abLastName;
		} else {
			self.name = @"";
		}
		
		ABMultiValue *abEmailAddresses = [myPerson valueForProperty:kABEmailProperty];
		
		NSUInteger count = [abEmailAddresses count];
		if (count > 0) {
			NSMutableArray *newEmailAddresses = [NSMutableArray arrayWithCapacity:count];
			for (NSUInteger i = 0; i < count; i++) {
				[newEmailAddresses addObject:[abEmailAddresses valueAtIndex:i]];
			}
			self.emailAddresses = [newEmailAddresses copy];	
			self.email = [emailAddresses objectAtIndex:0];
		} else {
			self.emailAddresses = nil;
			self.email = @"";
		}
	} else {
		self.name = @"";
		self.email = @"";
	}
	[pool drain];
}


- (BOOL)checkName {
	if ([name length] < 5) {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_NameToShort"), nil, nil, nil);
		return NO;
	}
	if ([name length] > 500) {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_NameToLong"), nil, nil, nil);
		return NO;
	}
	if ([name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]].length != 0) {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_InvalidCharInName"), nil, nil, nil);
		return NO;
	}
	if ([name characterAtIndex:0] <= '9' && [name characterAtIndex:0] >= '0') {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_NameStartWithDigit"), nil, nil, nil);
		return NO;
	}
	return YES;
}

- (BOOL)checkEmailMustSet:(BOOL)mustSet {
	if (!email) {
		email = @"";
	}
	
	if (!mustSet && [email length] == 0) {
		return YES;
	}
	if ([email length] > 254) {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_EmailToLong"), nil, nil, nil);
		return NO;
	}
	if ([email length] < 4) {
		goto emailIsInvalid;
	}
	if ([email hasPrefix:@"@"] || [email hasSuffix:@"@"] || [email hasSuffix:@"."]) {
		goto emailIsInvalid;
	}
	NSArray *components = [email componentsSeparatedByString:@"@"];
	if ([components count] != 2) {
		goto emailIsInvalid;
	} 
	if ([(NSString *)[components objectAtIndex:0] length] > 64) {
		goto emailIsInvalid;
	}
	
	NSMutableCharacterSet *charSet = [NSMutableCharacterSet characterSetWithRange:(NSRange){128, 65408}];
	[charSet addCharactersInString:@"01234567890_-+@.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
	[charSet invert];
	
	if ([[components objectAtIndex:0] rangeOfCharacterFromSet:charSet].length != 0) {
		goto emailIsInvalid;
	}
	[charSet addCharactersInString:@"+"];
	if ([[components objectAtIndex:1] rangeOfCharacterFromSet:charSet].length != 0) {
		goto emailIsInvalid;
	}
	
	return YES;
	
emailIsInvalid: //Hierher wird gesprungen, wenn die E-Mail-Adresse ungültig ist und nicht eine spezielle Meldung ausgegeben werden soll.
	NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_InvalidEmail"), nil, nil, nil);
	return NO;
}

- (BOOL)checkComment {
	if (!comment) {
		comment = @"";
		return YES;
	}
	if ([comment length] == 0) {
		return YES;
	}
	if ([comment length] > 500) {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_CommentToLong"), nil, nil, nil);			
		return NO;			
	}			
	if ([comment rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]].length != 0) {
		NSRunAlertPanel(localized(@"Warning"), localized(@"CheckWarning_InvalidCharInComment"), nil, nil, nil);			
		return NO;			
	}		
	return YES;
}


- (NSView *)displayedView {
	return displayedView;
}
- (void)setDisplayedView:(NSView *)value {
	if (displayedView != value) {
		if (displayedView == progressView) {
			[progressIndicator stopAnimation:nil];
		}		
		[displayedView removeFromSuperview];
		displayedView = value;
		if (value != nil) {
			NSRect oldRect, newRect;
			oldRect = [sheetWindow frame];
			newRect.size = [value frame].size;
			newRect.origin.x = oldRect.origin.x + (oldRect.size.width - newRect.size.width) / 2;
			newRect.origin.y = oldRect.origin.y + oldRect.size.height - newRect.size.height;
			
			[sheetWindow setFrame:newRect display:YES animate:YES];
			[sheetWindow setContentSize:newRect.size];			
			
			[sheetView addSubview:value];
			if (value == progressView) {
				[progressIndicator startAnimation:nil];
			}
		}
	}
}


- (NSInteger)keyType {
	return keyType;
}
- (void)setKeyType:(NSInteger)value {
	keyType = value;
	if (value == 2 || value == 3) {
		keyLengthFormatter.minKeyLength = 1024;
		keyLengthFormatter.maxKeyLength = 3072;
		self.length = [keyLengthFormatter checkedValue:length];
		self.availableLengths = [NSArray arrayWithObjects:@"1024", @"2048", @"3072", nil];
	} else {
		keyLengthFormatter.minKeyLength = 1024;
		keyLengthFormatter.maxKeyLength = 4096;
		self.length = [keyLengthFormatter checkedValue:length];
		self.availableLengths = [NSArray arrayWithObjects:@"1024", @"2048", @"3072", @"4096", nil];
	}
}


@end


@implementation KeyLengthFormatter
@synthesize minKeyLength;
@synthesize maxKeyLength;

- (NSString*)stringForObjectValue:(id)obj {
	return [obj description];
}

- (NSInteger)checkedValue:(NSInteger)value {
	if (value < minKeyLength) {
		value = minKeyLength;
	}
	if (value > maxKeyLength) {
		value = maxKeyLength;
	}
	return value;
}

- (BOOL)getObjectValue:(id*)obj forString:(NSString*)string errorDescription:(NSString**)error {
	*obj = [NSString stringWithFormat:@"%i", [self checkedValue:[string integerValue]]];
	return YES;
}

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**) newString errorDescription:(NSString**)error {
	if ([partialString rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet] options: NSLiteralSearch].length == 0) {
		return YES;
	} else {
		return NO;
	}
}

@end

